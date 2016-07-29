class AddGildedToCodons < ActiveRecord::Migration[5.0]
  def change
    add_column :codons, :gilded, :boolean, default: false
  end
end
