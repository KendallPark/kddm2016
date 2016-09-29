class DTreeGeneBreeder < TreeGeneBreeder


  def mate(gene_1, gene_2)
    operators = DTreeGene.operators

    crossover_1 = crossover(gene_1)
    crossover_2 = crossover(gene_2)

    temp = crossover_1.deep_dup
    crossover_1.clear
    crossover_1.merge!(crossover_2)
    crossover_2.clear
    crossover_2.merge!(temp)

    new_sequence_1 = gene_1.sequence
    new_sequence_2 = gene_2.sequence

    baby_1 = DTreeGene.new(sequence: new_sequence_1)
    baby_1.codon_mutations = codon_mutations(gene_1)
    baby_2 = DTreeGene.new(sequence: new_sequence_2)
    baby_2.codon_mutations = codon_mutations(gene_2)

    return [baby_1, baby_2]
  end

end
