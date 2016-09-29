class AddCrossingCacheToCodons < ActiveRecord::Migration[5.0]
  def change
    add_column :codons, :crossing_cache, :string
  end
end
