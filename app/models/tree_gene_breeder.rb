class TreeGeneBreeder < GeneBreeder

  def refine!
    babies = []
    @pool.each do |gene|
      next if gene.size > 25
      mutations = []
      gene.tree_traverse! do |node|
        mutations << node["codon_id"] if node["codon_id"]
      end
      mutations.each do |codon_id|
        new_gene = TreeGene.new(sequence: gene.sequence)
        new_gene.codon_mutations = [codon_id]
        babies << new_gene if new_gene.save
      end
    end
    babies
  end

  def breed!
    babies = []
    @pool.shuffle.each_slice(2) do |mother, father|
      return unless father
      kids = mate(mother, father)
      kids.each do |baby|
        babies << baby if baby.save
      end
    end
    babies
  end

  def mate(gene_1, gene_2)
    operators = TreeGene.operators

    crossover_1 = crossover(gene_1)
    crossover_2 = crossover(gene_2)

    if crossover_1["type"] && mutate?
      crossover_1["type"] = (operators - [crossover_1["type"]]).sample
    end
    if crossover_2["type"] && mutate?
      crossover_2["type"] = (operators - [crossover_2["type"]]).sample
    end

    temp = crossover_1.deep_dup
    crossover_1.clear
    crossover_1.merge!(crossover_2)
    crossover_2.clear
    crossover_2.merge!(temp)

    new_sequence_1 = gene_1.sequence
    new_sequence_2 = gene_2.sequence

    baby_1 = TreeGene.new(sequence: new_sequence_1)
    baby_1.codon_mutations = codon_mutations(gene_1)
    baby_2 = TreeGene.new(sequence: new_sequence_2)
    baby_2.codon_mutations = codon_mutations(gene_2)

    return [baby_1, baby_2]
  end

  def codon_mutations(gene)
    mutations = []
    gene.tree_traverse! do |node|
      mutations << node["codon_id"] if node["codon_id"] && mutate?
    end
  end

  def crossover(gene)
    index = Random.rand(0..(gene.gene_size-1))
    count = 0
    gene.tree_traverse! do |node|
      return node if count == index
      count += 1
    end
  end
end
