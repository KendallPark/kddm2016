class CreateJoinTableCodonGene < ActiveRecord::Migration[5.0]
  def change
    create_join_table :codons, :genes do |t|
      t.index [:codon_id, :gene_id]
      t.index [:gene_id, :codon_id]
    end
  end
end
