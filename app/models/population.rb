class Population
  def initalize(genes, codons)
    @genes = genes || new_genes
    @codons = codons || new_codons
  end

  attr_reader :genes

  def new_codons
    100.times do

    end
  end

  def new_genes

  end

  def compute_fitness!
    @genes.each do

    end
  end
end
