class AddSizeToGene < ActiveRecord::Migration[5.0]
  def change
    add_column :genes, :size, :integer
    TreeGene.in_batches(of: 100) do |genes|
      genes.each { |gene| gene.update!(size: gene.gene_size) }
    end
  end
end
