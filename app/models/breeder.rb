class Breeder
  def initialize(options={})
    @codons = options[:codons]
    @mutation_rate = options[:mutation_rate] || 0.05
  end

  def breed!
    babies = []
    @codons.shuffle.each_slice(2) do |codon_1, codon_2|
      return unless codon_2
      baby = mate(codon_1, codon_2)
      baby.save!
      babies << baby
    end
    babies
  end

  def mate(codon_1, codon_2)
    parents = [codon_1, codon_2]
    lab_type = codon_1.lab_type

    value_start = mutate? ? nil : parents.sample.value_start
    value_end = mutate? ? nil : parents.sample.value_end
    date_start = mutate? ? nil : parents.sample.date_start
    date_end = mutate? ? nil : parents.sample.date_end

    baby = Codon.new( lab_type: lab_type,
                      value_start: value_start,
                      value_end: value_end,
                      date_start: date_start,
                      date_end: date_end )
  end

  def mutate?
    Random.rand <= @mutation_rate
  end

end
