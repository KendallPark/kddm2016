class AddTypeToGenes < ActiveRecord::Migration[5.0]
  def change
    add_column :genes, :type, :string
  end
end
