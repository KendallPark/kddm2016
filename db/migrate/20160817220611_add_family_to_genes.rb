class AddFamilyToGenes < ActiveRecord::Migration[5.0]
  def change
    add_column :genes, :family, :string
  end
end
