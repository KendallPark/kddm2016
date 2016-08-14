class GenePool
  def initialize(options={})
    @size = options[:size] || 1000
    @selection_size = options[:selection_size] || 10
    compute_stragglers!
    new_genes!
  end

  attr_reader :lab_type, :size, :selection_size

  def genes
    Gene.by_fitness
  end

  def fittest_genes
    Gene.by_uniq_fitness
  end

  def stragglers
    Gene.where(fitness: nil)
  end

  def select_genes
    fittest_genes.first(selection_size)
  end

  def alpha
    genes.first
  end

  def stats
    top_dogs = select_genes
    top_dog = top_dogs.first
    message = top_dog.stats
    top_dogs.each do |dog|
      message << "    #{dog.id}: #{dog.fitness}\n"
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
    fittest = select_genes
    puts "Selected #{fittest.length}: #{fittest.pluck(:id).to_s}"
    fittest.length.times do
      babies.concat(GeneBreeder.new({pool: fittest}).breed! || [])
    end
    compute_fitness!(babies)
    puts "Created #{babies.length}: #{babies.pluck(:id).to_s}"
  end

  def new_genes!
    babies = []
    print "Making fresh genes"
    (size - Gene.count).times do
      gene = Gene.new
      babies << gene if gene.save
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
    count = Gene.count - size
    return unless count > 0
    genes.by_fitness.last(count).delete_all
  end

  def reevaluate!(the_genes)
    the_genes
    Parallel.each(the_genes, in_threads: 4) do |gene|
      ActiveRecord::Base.connection_pool.with_connection do
        gene.evaluate!
      end
    end
  end

  def compute_fitness!(the_genes)
    self.class.compute_fitness!(the_genes)
  end

  def self.compute_fitness!(the_genes)
    print "Computing Fitness"
    the_genes.each do |gene|
      print "."
      if gene.invalid?
        gene.destroy!
      else
        gene.fitness! do |true_pos, true_neg, false_pos, false_neg, sens, spec, ppv, npv, lr_pos, lr_neg, accuracy|
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
