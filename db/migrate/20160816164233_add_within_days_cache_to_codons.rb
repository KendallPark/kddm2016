class AddWithinDaysCacheToCodons < ActiveRecord::Migration[5.0]
  def change
    add_column :codons, :within_days_cache, :string
  end
end
