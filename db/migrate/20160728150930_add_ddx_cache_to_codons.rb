class AddDdxCacheToCodons < ActiveRecord::Migration[5.0]
  def change
    add_column :codons, :dx_cache, :string
  end
end
