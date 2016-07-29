class Breeder
  def initialize(options={})
    @codons = options[:codons]
    @mutation_rate = options[:mutation_rate] || 0.1
  end

  def breed!
    babies = []
    @codons.shuffle.each_slice(2) do |codon_1, codon_2|
      return unless codon_2
      baby = mate(codon_1, codon_2)
      babies << baby if baby.save
    end
    babies
  end

  def mate(codon_1, codon_2)
    lab_type = codon_1.lab_type

    start_vals = [codon_1.val_start, codon_2.val_start].sort
    end_vals = [codon_1.val_end, codon_2.val_end].sort
    hours = [codon_1.hours_after_surgery, codon_2.hours_after_surgery].sort

    value_start = mutate? ? nil : Random.rand(start_vals.first..start_vals.last)
    value_end = mutate? ? nil : Random.rand(end_vals.first..end_vals.last)
    hours_after_surgery = mutate? ? nil : Random.rand(hours.first..hours.last)

    baby = Codon.new( lab_type: lab_type,
                      val_start: value_start,
                      val_end: value_end,
                      hours_after_surgery: hours_after_surgery )
  end

  def mutate?
    Random.rand <= @mutation_rate
  end

end
