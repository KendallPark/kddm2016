class AllelePool
  def initialize(options={})
    @lab_type = LabType.by_number_of_patients[options[:lab_index]] if options[:lab_index]
    @lab_type ||= options[:lab_type] || LabType.by_number_of_patients.first
    @size = options[:size] || 100
    @codons = options[:codons] || load_fittest_codons!
    @selection_size = options[:selection_size] || 10
    new_codons! if @codons.empty?
    load_fittest_codons!
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

  def alpha_ppv
    alpha.ppv
  end

  def alpha_npv
    alpha.npv
  end

  def alpha_days
    # "#{alpha.end_hours/60} - #{alpha.start_hours/60}"
    "#{alpha.start_hours/60}"
  end

  def alpha_range
    "#{alpha.start_value} - #{alpha.end_value}"
  end

  def stats
    <<-MESSAGE
    ////////////////////////////////////////
    // #{lab_type.name}
    ////////////////////////////////////////
    Days: #{alpha_days}
    Range: #{alpha_range}
    Sens: #{(alpha_sens*100).to_i}%
    Spec: #{(alpha_spec*100).to_i}%
    +LR: #{alpha.lr_pos}
    -LR: #{alpha.lr_neg}
    PPV: #{(alpha_ppv*100).to_i}%
    NPV: #{(alpha_npv*100).to_i}%
    Fit: #{alpha_fitness}

    MESSAGE
  end

  def breed_generations!(generations=1)
    generations.times do
      load_fittest_codons!
      breed_fittest!
    end
  end

  def breed_fittest!
    babies = []
    selection_size.times do
      babies.concat(Breeder.new({codons: select_codons}).breed!)
    end
    compute_fitness!(babies)
  end

  def load_fittest_codons!
    codons = Codon.where(lab_type: lab_type).where.not(fitness: nil).by_fitness.first(size)
  end

  def new_codons!
    size.times do
      codon = Codon.new(lab_type: lab_type)
      codons << codon if codon.save
    end
    compute_fitness!(codons)
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
    the_codons.each do |codon|
      if codon.invalid?
        codon.destroy!
      else
        codon.fitness! do |true_pos, true_neg, false_pos, false_neg, sens, spec, ppv, npv, lr_pos, lr_neg|
          if sens > 0.5 && spec > 0.5
            (sens+ppv)/2
          else
            (sens+ppv)/2*0.1
          end
        end
      end
    end
  end
end
