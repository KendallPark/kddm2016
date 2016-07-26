class AddFitnessToCodons < ActiveRecord::Migration[5.0]
  def change
    add_column :codons, :fitness, :decimal
  end
end
