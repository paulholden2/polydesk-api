class PrefabQuery < ResourceQuery
  attr_reader :inner_scope

  def initialize(payload, inner_scope: Prefab.all)
    super(payload)
    @inner_scope = inner_scope
  end

  protected

  def apply_function(scope, ast)
    case ast.name
    when 'lookup_s'
      apply_function_lookup(scope, 'text', ast)
    when 'lookup_i'
      apply_function_lookup(scope, 'integer', ast)
    when 'lookup_f'
      apply_function_lookup(scope, 'float', ast)
    when 'lookup_b'
      apply_function_lookup(scope, 'boolean', ast)
    when 'referent_sum'
      apply_function_referent_aggregate(scope, 'numeric', 'sum', ast)
    when 'referent_avg'
      apply_function_referent_aggregate(scope, 'numeric', 'avg', ast)
    when 'referent_min'
      apply_function_referent_aggregate(scope, 'numeric', 'min', ast)
    when 'referent_max'
      apply_function_referent_aggregate(scope, 'numeric', 'max', ast)
    when 'referent_count'
      apply_function_referent_count(scope, ast)
    when 'referent_count_distinct'
      apply_function_referent_count_distinct(scope, ast)
    else
      super
    end
  end

  def apply_function_referent_count_distinct(scope, ast)
    namespace, referrer, dimension = ast.children

    if namespace.is_a?(Keisan::AST::Literal)
      if !namespace.value.match(/^[a-z]+$/)
        raise Polydesk::Errors::GeneratorFunctionArgumentError.new("Argument at index 0 for #{ast.name}() is a literal with disallowed characters")
      else
        namespace = namespace.value
        if !namespace.is_a?(String)
          raise Polydesk::Errors::GeneratorFunctionArgumentError.new("Argument at index 0 for #{ast.name}() must be a string")
        end
      end
    else
      scope, namespace = apply_ast(scope, namespace)
    end

    if referrer.is_a?(Keisan::AST::Literal)
      if !referrer.value.match(/^[-_.a-zA-Z0-9]+$/)
        raise Polydesk::Errors::GeneratorFunctionArgumentError.new("Argument at index 1 for #{ast.name}() is a literal with disallowed characters")
      else
        referrer = referrer.value
        if !referrer.is_a?(String)
          raise Polydesk::Errors::GeneratorFunctionArgumentError.new("Argument at index 1 for #{ast.name}() must be a string")
        end
      end
    else
      scope, referrer = apply_ast(scope, referrer)
    end

    if dimension.is_a?(Keisan::AST::Literal)
      if !dimension.value.match(/^[-_.a-zA-Z0-9]+$/)
        raise Polydesk::Errors::GeneratorFunctionArgumentError.new("Argument at index 2 for #{ast.name}() is a literal with disallowed characters")
      else
        dimension = dimension.value
        if !dimension.is_a?(String)
          raise Polydesk::Errors::GeneratorFunctionArgumentError.new("Argument at index 2 for #{ast.name}() must be a string")
        end
      end
    else
      scope, dimension = apply_ast(scope, dimension)
    end

    apply_referent_count_distinct(scope, namespace, referrer, dimension)
  end

  def apply_referent_count_distinct(scope, namespace, referrer, dimension)
    remote_table_alias = "referent_aggregate#{next_lookup_id}___#{referrer.gsub('.', '__')}"
    local_uid = "(#{scope.table_name}.namespace || '/' || #{scope.table_name}.tag)"
    remote_table_alias_inner = "#{remote_table_alias}___inner"
    namespace_col = column_name(scope, remote_table_alias_inner, 'namespace')
    referrer_col = column_name(scope, remote_table_alias_inner, referrer)
    dimension_col = column_name(scope, remote_table_alias_inner, dimension)
    scope = scope.joins(
      <<-SQL
        left join (
                    select
                      count(distinct (#{dimension_col})) as result,
                      #{referrer_col} as referent
                    from (#{inner_scope.to_sql}) as #{remote_table_alias_inner}
                    where #{namespace_col} = '#{namespace}'
                    group by #{referrer_col}
                  ) as #{remote_table_alias}
                  on #{remote_table_alias}.referent = #{local_uid}
      SQL
    )
    return scope, "(coalesce(#{remote_table_alias}.result, 0))"
  end

  def apply_function_referent_count(scope, ast)
    namespace, referrer = ast.children

    if namespace.is_a?(Keisan::AST::Literal)
      if !namespace.value.match(/^[a-z]+$/)
        raise Polydesk::Errors::GeneratorFunctionArgumentError.new("Argument at index 0 for #{ast.name}() is a literal with disallowed characters")
      else
        namespace = namespace.value
        if !namespace.is_a?(String)
          raise Polydesk::Errors::GeneratorFunctionArgumentError.new("Argument at index 0 for #{ast.name}() must be a string")
        end
      end
    else
      scope, namespace = apply_ast(scope, namespace)
    end

    if referrer.is_a?(Keisan::AST::Literal)
      if !referrer.value.match(/^[-_.a-zA-Z0-9]+$/)
        raise Polydesk::Errors::GeneratorFunctionArgumentError.new("Argument at index 1 for #{ast.name}() is a literal with disallowed characters")
      else
        referrer = referrer.value
        if !referrer.is_a?(String)
          raise Polydesk::Errors::GeneratorFunctionArgumentError.new("Argument at index 1 for #{ast.name}() must be a string")
        end
      end
    else
      scope, referrer = apply_ast(scope, referrer)
    end

    apply_referent_count(scope, namespace, referrer)
  end

  def apply_referent_count(scope, namespace, referrer)
    remote_table_alias = "referent_aggregate#{next_lookup_id}___#{referrer.gsub('.', '__')}"
    local_uid = "(#{scope.table_name}.namespace || '/' || #{scope.table_name}.tag)"
    remote_table_alias_inner = "#{remote_table_alias}___inner"
    namespace_col = column_name(scope, remote_table_alias_inner, 'namespace')
    referrer_col = column_name(scope, remote_table_alias_inner, referrer)
    scope = scope.joins(
      <<-SQL
        left join (
                    select
                      count(#{remote_table_alias_inner}.id) as result,
                      #{referrer_col} as referent
                    from (#{inner_scope.to_sql}) as #{remote_table_alias_inner}
                    where #{namespace_col} = '#{namespace}'
                    group by #{referrer_col}
                  ) as #{remote_table_alias}
                  on #{remote_table_alias}.referent = #{local_uid}
      SQL
    )
    return scope, "(coalesce(#{remote_table_alias}.result, 0))"
  end

  def apply_function_referent_aggregate(scope, cast, func, ast)
    namespace, referrer, dimension = ast.children

    if namespace.is_a?(Keisan::AST::Literal)
      if !namespace.value.match(/^[a-z]+$/)
        raise Polydesk::Errors::GeneratorFunctionArgumentError.new("Argument at index 0 for #{ast.name}() is a literal with disallowed characters")
      else
        namespace = namespace.value
        if !namespace.is_a?(String)
          raise Polydesk::Errors::GeneratorFunctionArgumentError.new("Argument at index 0 for #{ast.name}() must be a string")
        end
      end
    else
      scope, namespace = apply_ast(scope, namespace)
    end

    if referrer.is_a?(Keisan::AST::Literal)
      if !referrer.value.match(/^[-_.a-zA-Z0-9]+$/)
        raise Polydesk::Errors::GeneratorFunctionArgumentError.new("Argument at index 1 for #{ast.name}() is a literal with disallowed characters")
      else
        referrer = referrer.value
        if !referrer.is_a?(String)
          raise Polydesk::Errors::GeneratorFunctionArgumentError.new("Argument at index 1 for #{ast.name}() must be a string")
        end
      end
    else
      scope, referrer = apply_ast(scope, referrer)
    end

    if dimension.is_a?(Keisan::AST::Literal)
      if !dimension.value.match(/^[-_.a-zA-Z0-9]+$/)
        raise Polydesk::Errors::GeneratorFunctionArgumentError.new("Argument at index 2 for #{ast.name}() is a literal with disallowed characters")
      else
        dimension = dimension.value
        if !dimension.is_a?(String)
          raise Polydesk::Errors::GeneratorFunctionArgumentError.new("Argument at index 2 for #{ast.name}() must be a string")
        end
      end
    else
      scope, dimension = apply_ast(scope, dimension)
    end

    apply_referent_aggregate(scope, cast, func, namespace, referrer, dimension)
  end

  def apply_referent_aggregate(scope, cast, func, namespace, referrer, dimension)
    remote_table_alias = "referent_aggregate#{next_lookup_id}___#{referrer.gsub('.', '__')}"
    local_uid = "(#{scope.table_name}.namespace || '/' || #{scope.table_name}.tag)"
    remote_table_alias_inner = "#{remote_table_alias}___inner"
    namespace_col = column_name(scope, remote_table_alias_inner, 'namespace')
    referrer_col = column_name(scope, remote_table_alias_inner, referrer)
    dimension_col = column_name(scope, remote_table_alias_inner, dimension)
    scope = scope.joins(
      <<-SQL
        left join (
                    select
                      #{func}((#{dimension_col})::#{cast}) as result,
                      #{referrer_col} as referent
                    from #{scope.table_name} as #{remote_table_alias_inner}
                    where #{namespace_col} = '#{namespace}'
                    group by #{referrer_col}
                  ) as #{remote_table_alias}
                  on #{remote_table_alias}.referent = #{local_uid}
      SQL
    )
    return scope, "(coalesce(#{remote_table_alias}.result, 0.0))"
  end

  # Apply a lookup join to the given scope
  #   - scope: The scope to apply the join to
  #   - cast: What type to cast the result as (unused)
  #   - local: Alias for the local data property that holds the reference to
  #            the remote prefab.
  #   - remote: Data key path for the value to be returned from the lookup.
  #
  # Returns the modified scope and generated SQL
  def apply_lookup(scope, cast, local, remote)
    remote_table_alias = "lookup#{next_lookup_id}___#{remote.gsub('.', '__')}"
    remote_uid = "(#{remote_table_alias}.namespace || '/' || #{remote_table_alias}.tag)"
    scope = scope.joins(
      <<-SQL
        left join (#{inner_scope.to_sql}) as #{remote_table_alias}
        on (#{local}::text) = #{remote_uid}
      SQL
      # and json_extract_path_text(#{remote_table_alias}.data::json, #{remote_table_alias}.namespace, 'inner') = 'prefabs'
    )
    return scope, "(#{column_name(scope, remote_table_alias, remote)}::#{cast})"
  end

  # Applies a lookup join to the given scope, returning the result converted
  # to the type provided by the cast argument.
  def apply_function_lookup(scope, cast, ast)
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
      scope, local = apply_ast(scope, local_arg)
    else
      if !local_arg.value.match(/^[-_.a-zA-Z0-9]+$/)
        raise Polydesk::Errors::GeneratorFunctionArgumentError.new("Argument at index 0 for #{ast.name}() is a literal with disallowed characters")
      end
      local = column_name(scope, 'prefabs', local_arg.value)
      if !local.is_a?(String)
        raise Polydesk::Errors::GeneratorFunctionArgumentError.new("Argument at index 0 for #{ast.name}() must be a string")
      end
    end

    if !remote_arg.is_a?(Keisan::AST::Literal)
      scope, remote = apply_ast(scope, remote_arg)
    else
      if !remote_arg.value.match(/^[-_.a-zA-Z0-9]+$/)
        raise Polydesk::Errors::GeneratorFunctionArgumentError.new("Argument at index 1 for #{ast.name}() is a literal with disallowed characters")
      end
      remote = remote_arg.value
      if !remote.is_a?(String)
        raise Polydesk::Errors::GeneratorFunctionArgumentError.new("Argument at index 1 for #{ast.name}() must be a string")
      end
    end

    apply_lookup(scope, cast, local, remote)
  end
end
