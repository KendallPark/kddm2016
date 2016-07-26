class AddMoreMetricsToCodons < ActiveRecord::Migration[5.0]
  def change
    add_column :codons, :true_positive, :integer
    add_column :codons, :false_positive, :integer
    add_column :codons, :true_negative, :integer
    add_column :codons, :false_negative, :integer
  end
end
