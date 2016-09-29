class AddSignatureToGenes < ActiveRecord::Migration[5.0]
  def change
    add_column :genes, :signature, :string
  end
end
