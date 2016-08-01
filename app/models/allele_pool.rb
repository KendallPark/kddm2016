class AllelePool
  def initialize(options={})
    @lab_type = LabType.by_number_of_patients[options[:lab_index]] if options[:lab_index]
    @lab_type ||= options[:lab_type] || LabType.by_number_of_patients.first
    @size = options[:size] || 1000
    @selection_size = options[:selection_size] || 10
    puts lab_type.name
    compute_stragglers!
    new_codons!
  end

  attr_reader :lab_type, :size, :codons, :selection_size

  def codons
    Codon.where(lab_type: lab_type).by_fitness
  end

  def fittest_codons
    Codon.where(lab_type: lab_type).by_uniq_fitness
  end

  def stragglers
    Codon.where(lab_type: lab_type).where(fitness: nil)
  end

  def select_codons
    fittest_codons.first(selection_size)
  end

  def alpha
    codons.first
  end

  def stats
    top_dogs = select_codons
    top_dog = top_dogs.first
    message = top_dog.stats
    top_dogs.each do |dog|
      message << "    #{dog.id}: #{dog.fitness}  #{dog.range}  #{dog.days_after_surgery.round(3)}\n"
    end
    message << "\n"
    message
  end

  def breed_generations!(generations=1)
    generations.times do
      breed_fittest!
    end
  end

  def breed_fittest!
    babies = []
    fittest = select_codons
    puts "Selected #{fittest.length}: #{fittest.pluck(:id).to_s}"
    fittest.length.times do
      babies.concat(Breeder.new({codons: fittest}).breed! || [])
    end
    compute_fitness!(babies)
    puts "Created #{babies.length}: #{babies.pluck(:id).to_s}"
  end

  def load_fittest_codons!
    codons = fittest_codons.first(size)
  end

  def new_codons!
    babies = []
    print "Making fresh codons"
    (size - lab_type.codons.length).times do
      codon = Codon.new(lab_type_id: lab_type.id)
      babies << codon if codon.save
      print "."
    end
    puts ""
    puts "Population of #{babies.length}: #{babies.pluck(:id).to_s}"
    compute_fitness!(babies)
  end

  def compute_stragglers!
    compute_fitness!(stragglers)
  end

  def cull_weaklings!
    count = lab_type.codons.length - size
    return unless count > 0
    lab_type.codons.by_fitness.last(count).delete_all
  end

  def reevaluate!(the_codons)
    the_codons
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
    print "Computing Fitness"
    the_codons.each do |codon|
      print "."
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
    puts ""
  end
end
