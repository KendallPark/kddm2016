class RemoveRequirementsFromPatients < ActiveRecord::Migration[5.0]
  def change
    change_column_null :patients, :infection, true
  end
end
