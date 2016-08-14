class GeneBreeder < Breeder
  def mate(gene_1, gene_2)
    new_sequence = {}
    codon_mutations = []
    weight_mutations = []
    lab_type_ids = gene_1.sequence.keys | gene_2.sequence.keys
    lab_type_ids.each do |lab_type_id|
      codons = []
      codon_1 = gene_1.sequence[lab_type_id]
      codon_2 = gene_2.sequence[lab_type_id]
      codons << codon_1 if codon_1
      codons << codon_2 if codon_2

      new_sequence[lab_type_id] = codons.sample

      codon_mutations << lab_type_id if mutate?
      weight_mutations << lab_type_id if mutate?
    end

    baby = Gene.new(sequence: new_sequence)
    baby.codon_mutations = codon_mutations
    baby.weight_mutations = weight_mutations
    baby
  end
end
