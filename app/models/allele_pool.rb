class AllelePool
  def initialize(options={})
    @lab_type = options[:lab_type] || LabType.by_number_of_patients.first
    @size = options[:size] || 100
    @codons = options[:codons] || load_fittest_codons!
    @selection_size = options[:selection_size] || 10
  end

  attr_reader :lab_type, :size, :codons, :selection_size

  def select_codons
    codons.first(selection_size)
  end

  def alpha
    codons.first.reload
  end

  def alpha_fitness
    alpha.fitness.to_s
  end

  def alpha_sens
    alpha.sensitivity
  end

  def alpha_spec
    alpha.specificity
  end

  def alpha_days
    "#{alpha.end_hours/60} - #{alpha.start_hours/60}"
  end

  def breed_generations!(generations=10)
    generations.times do
      load_fittest_codons!
      breed_fittest!
    end
  end

  def breed_fittest!
    babies = []
    Parallel.each((0..selection_size/2), in_threads: 4) do
      ActiveRecord::Base.connection_pool.with_connection do
        babies.concat(Breeder.new({codons: select_codons}).breed!)
      end
    end
    compute_fitness!(babies)
  end

  def load_fittest_codons!
    codons = Codon.where(lab_type: lab_type).where.not(fitness: nil).by_fitness.first(size)
  end

  def new_codons!
    size.times do
      codon = Codon.new(lab_type: lab_type)
      codon.save!
      codons << codon
    end
  end

  def compute_stragglers!
    compute_fitness!(Codon.where(lab_type: lab_type).where(fitness: nil))
  end

  def reevaluate!(the_codons)
    the_codons ||= codons
    Parallel.each(the_codons, in_threads: 4) do |codon|
      ActiveRecord::Base.connection_pool.with_connection do
        codon.evaluate!
      end
    end
  end

  def patient_popuation
    lab_type.number_of_patients
  end

  def compute_fitness!(the_codons)
    the_codons ||= codons
    Parallel.each(the_codons, in_threads: 4) do |codon|
      ActiveRecord::Base.connection_pool.with_connection do
        codon.fitness! do |true_pos, true_neg, false_pos, false_neg, sens, spec|
          correctly_identified = (true_pos.to_f + true_neg.to_f)/patient_popuation
          not_correctly_identified = 1 - correctly_identified
          (sens**0.5 + spec**0.5)**2 + correctly_identified - not_correctly_identified
        end
      end
    end
  end
end
