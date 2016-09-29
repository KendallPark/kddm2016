class AddMoreCachesToCodons < ActiveRecord::Migration[5.0]
  def change
    add_column :codons, :ever_cache, :string
    add_column :codons, :ratio_cache, :string
    add_column :codons, :threshold, :float, default: Random.rand
    remove_column :codons, :value_start_id, :integer
    remove_column :codons, :value_end_id, :integer
    remove_column :codons, :date_start_id, :integer
    remove_column :codons, :date_end_id, :integer
  end
end
