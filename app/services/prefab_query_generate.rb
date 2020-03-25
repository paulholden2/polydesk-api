# This class generates custom columns using expressions that are parsed and
# converted into SQL. These expressions are not directly injected into the
# query string. The expression is parsed into an AST which, when traversed,
# will execute joins and/or selects on the given scope. Any literal values
# (which are directly inserted into the query) are scrubbed to prevent SQL
# injection; functions and operators are inserted as pre-defined SQL analogs,
# e.g. SQL CONCAT() expressions are generated from the concat() generator
# expression. This is basically a transpiler that whitelists SQL functions
# and provides a more URL- and human-friendly syntax.
#
#   To get a nested data value with SQL:
#     data#>>'{address,city}'
#
#   Using generator expressions:
#     prop("data.address.city")
#
# Additionally, things like joins and selects can't be done if raw SQL is
# simply passed as a query parameter. To do a lookup, for example, you have
# to join the Prefab table under a new alias and add it to the select clauses.
# This would require having two separate SQL clauses passed somehow in a
# single query hash value. With generator expressions, it is simply an
# easy-to-use formula:
#
#    ?generate[job_title]=lookup_s("data.job", "data.title")
#
# The above matches a Prefab with the UID stored in the "job" property and
# returns the value at "job_title" on the matched Prefab (as a string).
#
# Other areas of concern are column identifiers and table aliases: column
# identifiers are scrubbed upon initializing the PrefabQueryGenerate object
# to ensure no malicious SQL makes its way into the query. Table aliases are
# generated using simple character replacement on the Prefab data key paths.
# Since Blueprints will reject any schema with object properties that have
# keys containing characters other than alphanumerics, underscores, and
# dashes, the only character that could cause issues in the table alias is
# the path separator (dots). This is replaced and the resulting table alias
# consists of only alphanumerics, underscores, dashes, and dots. A regex
# match is used to verify this as an added layer of security.
#
# Column identifiers must consist only of alphanumerics and underscores (but
# may not begin with a number, and be distinct from the built-in attributes
# of the Prefab model.
#
# The generate query parameter must be a hash, where each key is a column
# identifier, and the corresponding value is an expression called a generator.
# If an error occurs during the evaluation of a generator, the entire query
# fails, not just the offending Prefab. This can be avoided by ensuring
# uniformity across all Prefabs using well-managed migrations to deal with
# evolving models.
class PrefabQueryGenerate
  attr_reader :payload, :generate, :generated_columns

  def initialize(payload)
    @payload = payload.deep_dup
    # A counter that is used to give each lookup table alias a unique number
    # to prevent alias conflicts when chaining lookups that return values at
    # the same path, e.g. lookup_s(lookup_s("data.a", "data.b"), "data.b")
    # In this example, both lookups will end up with the same assigned table
    # alias.
    @lookup_id = 0
    @generated_columns = {}
    load
  end

  def apply(scope)
    applied = scope
    generate.each { |key, value|
      applied, sql = evaluate_generator(applied, key, value)
      @generated_columns[key] = sql
    }
    applied
  end

  def apply_ast(scope, identifier, ast)
    case ast
    when Keisan::AST::ArithmeticOperator
      sql = ast.children.map { |operand|
        scope, operand_sql = apply_ast(scope, identifier, operand)
        operand_sql
      }.join(ast.class.symbol.to_s)
      sql = "(#{sql})"
    when Keisan::AST::UnaryOperator
      scope, operand_sql = apply_ast(scope, identifier, ast.children.first)
      sql = "#{ast.class.symbol.to_s}(#{operand_sql})"
    when Keisan::AST::Function
      scope, sql = apply_function(scope, identifier, ast)
    when Keisan::AST::String
      sql = "#{ActiveRecord::Base.connection.quote(ast.value)}"
    when Keisan::AST::Number
      sql = "#{ast.value}"
    when Keisan::AST::Boolean
      sql = "#{ast.value}"
    else
      sql = 'null'
    end
    return scope, sql
  end

  def evaluate_generator(scope, identifier, generator)
    calculator = Keisan::Calculator.new
    ast = calculator.ast(generator)
    scope, sql = apply_ast(scope, identifier, ast)
    return scope.select_append("(#{sql}) as \"#{identifier}\""), sql
  end

  private

  def next_lookup_id
    @lookup_id += 1
  end

  def column_name(table_alias, identifier)
    if identifier.start_with?("data.")
      path = identifier.split('.')[1..-1]
      "((#{table_alias}.data)\#>>'{#{path.join(',')}}')"
    else
      "(#{table_alias}.#{identifier})"
    end
  end

  # Apply a lookup join to the given scope
  #   - scope: The scope to apply the join to
  #   - identifier: Generated column identifier
  #   - cast: What type to cast the result as (unused)
  #   - local: Alias for the local data property that holds the reference to
  #            the remote prefab.
  #   - remote: Data key path for the value to be returned from the lookup.
  #
  # Returns the modified scope and the column identifier for the value
  # returned by the lookup.
  def apply_lookup(scope, identifier, cast, local, remote)
    remote_table_alias = "lookup#{next_lookup_id}___#{remote.gsub('.', '__')}"
    remote_uid = "(#{remote_table_alias}.namespace || '/' || #{remote_table_alias}.tag)"
    scope = scope.joins(
      <<-SQL
        left join prefabs as #{remote_table_alias}
        on (#{local}::text) = #{remote_uid}
      SQL
      # and json_extract_path_text(#{remote_table_alias}.data::json, #{remote_table_alias}.namespace, 'inner') = 'prefabs'
    )
    return scope, column_name(remote_table_alias, remote)
  end

  # Applies a lookup join to the given scope, returning the result converted
  # to the type provided by the cast argument.
  def apply_function_lookup(scope, cast, identifier, ast)
    local_arg, remote_arg = ast.children

    # The following 2 if-else blocks retrieve the local and remote aliases
    # to insert into the query. If the local and remote aliases are specified
    # using literals, there's a potential for SQL injection since they are
    # inserted directly into the query as given. Any disallowed characters
    # will raise a generator argument error. Non-lookup functions and
    # operators expressions are already converted into SQL expressions that
    # don't need scrubbing. When another lookup is passed as an argument,
    # it is inserted as the resulting column alias, and so doesn't need to
    # be scrubbed.

    if !local_arg.is_a?(Keisan::AST::Literal)
      scope, local = apply_ast(scope, identifier, local_arg)
    else
      if !local_arg.value.match(/^[-_.a-zA-Z0-9]+$/)
        raise Polydesk::Errors::GeneratorFunctionArgumentError.new("Argument at index 0 for #{ast.name}() is a literal with disallowed characters")
      end
      local = column_name('prefabs', local_arg.value)
      if !local.is_a?(String)
        raise Polydesk::Errors::GeneratorFunctionArgumentError.new("Argument at index 0 for #{ast.name}() must be a string")
      end
    end

    if !remote_arg.is_a?(Keisan::AST::Literal)
      scope, remote = apply_ast(scope, identifier, remote_arg)
    else
      if !remote_arg.value.match(/^[-_.a-zA-Z0-9]+$/)
        raise Polydesk::Errors::GeneratorFunctionArgumentError.new("Argument at index 1 for #{ast.name}() is a literal with disallowed characters")
      end
      remote = remote_arg.value
      if !remote.is_a?(String)
        raise Polydesk::Errors::GeneratorFunctionArgumentError.new("Argument at index 1 for #{ast.name}() must be a string")
      end
    end

    apply_lookup(scope, identifier, cast, local, remote)
  end

  def apply_function_concat(scope, identifier, ast)
    args = ast.children.map { |arg|
      scope, sql = apply_ast(scope, identifier, arg)
      "(#{sql}::text)"
    }

    return scope, "(concat(#{args.join(',')}))"
  end

  def apply_function_prop(scope, identifier, ast)
    arg = ast.children.first
    if arg.is_a?(Keisan::AST::String)
      if !arg.value.match(/^[-_.a-zA-Z0-9]+$/)
        raise Polydesk::Errors::GeneratorFunctionArgumentError.new("Argument at index 0 for #{ast.name}() is a literal with disallowed characters")
      end
      col = column_name(scope.table_name, arg.value)
    else
      scope, col = apply_ast(scope, identifier, arg)
    end
    return scope, col
  end

  def apply_function_sum(scope, cast, identifier, ast)
    arg = ast.children.first
    if arg.is_a?(Keisan::AST::String)
      if !arg.value.match(/^[-_.a-zA-Z0-9]+$/)
        raise Polydesk::Errors::GeneratorFunctionArgumentError.new("Argument at index 0 for #{ast.name}() is a literal with disallowed characters")
      end
      col = column_name('prefabs', arg.value)
    else
      scope, col = apply_ast(scope, identifier, arg)
    end
    return scope.group(:id), "sum((#{col})::#{cast})"
  end

  # Generate a SQL expression for the function specified in the given AST.
  # If applicable, updates and returns the given scope.
  def apply_function(scope, identifier, ast)
    case ast.name
    when 'lookup_s'
      apply_function_lookup(scope, 'text', identifier, ast)
    when 'lookup_i'
      apply_function_lookup(scope, 'integer', identifier, ast)
    when 'concat'
      apply_function_concat(scope, identifier, ast)
    when 'prop'
      apply_function_prop(scope, identifier, ast)
    when 'sum_i'
      apply_function_sum(scope, 'integer', identifier, ast)
    else
      return scope, 'null'
    end
  end

  def load
    query_generate = payload.fetch('generate', {})

    reserved_identifiers = Prefab.column_names
    query_generate.keys.each { |key|
      # Verify that no identifiers exactly match existing attributes.
      # Re-used identifiers will simply be overwritten, but we need to make
      # sure that attributes like namespace can't be replaced.
      if reserved_identifiers.include?(key)
        raise Polydesk::Errors::RestrictedGeneratedColumnIdentifier.new(key)
      end

      # Check that identifiers are using only alphanumerics and _, and
      # don't start with a number.
      if !key.match(/^[a-zA-Z_]+[a-zA-Z0-9_]*$/)
        raise Polydesk::Errors::InvalidGeneratedColumnIdentifier.new(key)
      end
    }

    @generate = query_generate
  end
end