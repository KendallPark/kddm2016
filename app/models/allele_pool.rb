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
    Codon.where(lab_type: lab_type).by_fitness.first(selection_size)
  end

  def alpha
    Codon.where(lab_type: lab_type).by_fitness.first
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
    "#{alpha.days_after_surgery}"
  end

  def alpha_range
    "#{alpha.start_value} - #{alpha.end_value}"
  end

  def stats
    top_dogs = select_codons
    top_dog = top_dogs.first
    <<-MESSAGE
    ////////////////////////////////////////
    // #{lab_type.name}
    ////////////////////////////////////////
    Days: #{top_dog.days_after_surgery}
    Range: #{top_dog.range}
    Sens: #{(top_dog.sensitivity*100).to_i}%
    Spec: #{(top_dog.specificity*100).to_i}%
    +LR: #{top_dog.lr_pos}
    -LR: #{top_dog.lr_neg}
    PPV: #{(top_dog.ppv*100).to_i}%
    NPV: #{(top_dog.npv*100).to_i}%
    0 Fit: #{top_dog.fitness}  #{top_dog.id}  #{top_dog.range}  #{top_dog.days_after_surgery.round(3)}
    1 Fit: #{top_dogs[1].fitness}  #{top_dogs[1].id}  #{top_dogs[1].range}  #{top_dogs[1].days_after_surgery.round(3)}
    2 Fit: #{top_dogs[2].fitness}  #{top_dogs[2].id}  #{top_dogs[2].range}  #{top_dogs[2].days_after_surgery.round(3)}
    3 Fit: #{top_dogs[3].fitness}  #{top_dogs[3].id}  #{top_dogs[3].range}  #{top_dogs[3].days_after_surgery.round(3)}
    4 Fit: #{top_dogs[4].fitness}  #{top_dogs[4].id}  #{top_dogs[4].range}  #{top_dogs[4].days_after_surgery.round(3)}
    5 Fit: #{top_dogs[5].fitness}  #{top_dogs[5].id}  #{top_dogs[5].range}  #{top_dogs[5].days_after_surgery.round(3)}
    6 Fit: #{top_dogs[6].fitness}  #{top_dogs[6].id}  #{top_dogs[6].range}  #{top_dogs[6].days_after_surgery.round(3)}
    7 Fit: #{top_dogs[7].fitness}  #{top_dogs[7].id}  #{top_dogs[7].range}  #{top_dogs[7].days_after_surgery.round(3)}
    8 Fit: #{top_dogs[8].fitness}  #{top_dogs[8].id}  #{top_dogs[8].range}  #{top_dogs[8].days_after_surgery.round(3)}
    9 Fit: #{top_dogs[9].fitness}  #{top_dogs[9].id}  #{top_dogs[9].range}  #{top_dogs[9].days_after_surgery.round(3)}

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
    fittest = select_codons
    puts "Selected #{fittest.count}: #{fittest.pluck(:id).to_s}"
    selection_size.times do
      babies.concat(Breeder.new({codons: fittest}).breed!)
    end
    compute_fitness!(babies)
    puts "Created #{babies.count}: #{babies.pluck(:id).to_s}"
  end

  def load_fittest_codons!
    codons = Codon.where(lab_type: lab_type).where.not(fitness: nil).by_fitness.first(size)
  end

  def new_codons!
    size.times do
      codon = Codon.new(lab_type: lab_type)
      codons << codon if codon.save
    end
    puts "Created #{codons.count}: #{codons.pluck(:id).to_s}"
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
