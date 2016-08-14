class AddSequenceToGenes < ActiveRecord::Migration[5.0]
  def change
    add_column :genes, :sequence, :hstore, null: false
    add_column :genes, :true_positive, :integer
    add_column :genes, :true_negative, :integer
    add_column :genes, :false_positive, :integer
    add_column :genes, :false_negative, :integer
    add_column :genes, :dx_cache, :string
    remove_column :genes, :generation, :integer
  end
end
