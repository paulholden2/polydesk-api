class AddDefaultSchemaToForms < ActiveRecord::Migration[5.2]
  def change
    change_column_default :forms, :schema, {}
  end
end
