class AllelePool
  def initialize(options={})
    @lab_type = LabType.by_number_of_patients[options[:lab_index]] if options[:lab_index]
    @lab_type ||= options[:lab_type] || LabType.by_number_of_patients.first
    @size = options[:size] || 100
    @codons = options[:codons] || load_fittest_codons!
    @selection_size = options[:selection_size] || 10
    new_codons!
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
    message = <<-MESSAGE
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

    MESSAGE
    top_dogs.each do |dog|
      message << "    #{dog.id}: #{dog.fitness}  #{dog.range}  #{dog.days_after_surgery.round(3)}\n"
    end
    message << "\n"
    message
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
    (size - codons.count).times do
      codon = Codon.new(lab_type: lab_type)
      codons << codon if codon.save
    end
    puts "Created #{codons.count}: #{codons.pluck(:id).to_s}"
    compute_fitness!(codons)
  end

  def compute_stragglers!
    compute_fitness!(Codon.where(lab_type: lab_type).where(fitness: nil))
  end

  def cull_weaklings!
    count = lab_type.codons.count - size
    return unless count > 0
    lab_type.codons.by_fitness.last(count).delete_all
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
            (sens+ppv)/2 * ([spec, sens].min)**2
          end
        end
      end
    end
  end
end
