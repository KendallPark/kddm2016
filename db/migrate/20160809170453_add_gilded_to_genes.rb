class AddGildedToGenes < ActiveRecord::Migration[5.0]
  def change
    add_column :genes, :gilded, :boolean, default: false
  end
end
