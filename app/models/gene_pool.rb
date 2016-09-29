class GenePool
  def initialize(options={})
    @size = options[:size] || 1000
    @selection_size = options[:selection_size] || 10
    @gene_model = Gene
    @gene_model = Object.const_get(options[:gene_model]) if options[:gene_model]
    puts @gene_model
    compute_stragglers!
    # new_genes!
  end

  attr_reader :lab_type, :size, :selection_size, :gene_model

  def breeder
    Object.const_get("#{gene_model.to_s}Breeder")
  end

  def genes
    gene_model.by_fitness
  end

  def fittest_genes
    gene_model.by_uniq_sig
  end

  def stragglers
    gene_model.where(fitness: nil)
  end

  def top_dogs
    fittest_genes.first(selection_size)
  end

  def select_genes_from(pop, select_size, exclude_alpha=false, gene_size=nil)
    if gene_size
      pool = pop.by_uniq_sig(gene_size).to_a
    else
      pool = pop.by_uniq_sig(3).to_a
    end
    pop_size = pool.length
    return [] if pop_size == 0
    alpha = pop.by_uniq_sig.first
    # alpha = pool.first
    indexes = {0 => true}
    selection = []
    selection << alpha unless exclude_alpha
    sigs = {}
    counter = 0
    while selection.count <= select_size && counter < select_size*5
      print "?"
      counter += 1
      index = (Random.rand**(5) * pop_size).to_i
      unless indexes[index]
        gene = pool[index]
        next if sigs.include? gene.signature
        selection << gene if gene
        indexes[index] = true
        sigs[gene.signature] = true
      end
    end
    selection.compact
  end

  def select_genes
    select_genes_from(gene_model.where.not(fitness: nil).all, selection_size)
  end

  def alpha
    gene_model.by_uniq_sig.first
  end

  def stats
    top_dog = top_dogs.first
    message = top_dog.stats
    top_dogs.each do |dog|
      message << "#{dog.id}: #{dog.fitness}  size: #{dog.size}  #{dog.tree_string[0, 60]}\n"
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
    puts "Selected #{fittest.length}:"
    fittest.each do |f|
      puts f.fitness.to_s+": "+f.tree_string[0,60]+"\n"
    end
    5.times do
      babies.concat(breeder.new({pool: fittest}).breed! || [])
    end
    compute_fitness!(babies)
    puts "Created #{babies.length}: #{babies.pluck(:id).to_s}"
  end

  def breed_little_ones!
    gene_model.sizes.each do |gene_size|
      next if gene_size == 1
      break if gene_size > 20
      refine_fittest!(gene_size) if gene_size == 3
      pop = gene_model.where(size: gene_size)
      exclude_alpha = gene_size == 1
      fittest = select_genes_from(pop, selection_size, exclude_alpha, gene_size)
      puts "Selected #{fittest.length} of size #{gene_size}:"
      fittest.each {|f| puts f.fitness.to_s+": "+f.signature[0,60]+"\n" }
      babies = breeder.new({pool: fittest}).breed! || []
      compute_fitness!(babies)
      puts "Created #{babies.length}: #{babies.pluck(:id).to_s}"
    end
  end

  def refine_fittest!(size=nil)
    if size
      pop = gene_model.where.not(fitness: nil).all
    else
      pop = gene_model.where.not(fitness: nil).where(size: size)
    end
    fittest = select_genes_from(pop, selection_size, false, size)
    puts "Refining fittest genes"
    babies = breeder.new({pool: fittest}).refine! || []
    compute_fitness!(babies)
    puts "Created #{babies.length}: #{babies.pluck(:id).to_s}"
  end

  def new_genes!(poolsize=nil)
    babies = []
    print "Making fresh genes"
    poolsize ||= size
    # poolsize = (size - gene_model.count) if poolsize < (size - gene_model.count)
    poolsize.times do
      gene = gene_model.new
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
    count = gene_model.count - size
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
      if gene.invalid?
        print "x"
        gene.destroy!
      else
        gene.fitness! do |true_pos, true_neg, false_pos, false_neg, sens, spec, ppv, npv, lr_pos, lr_neg, accuracy, size|
          size ||= 1
          # if sens < 0.5
          #   print "x"
          #   :destroy
          total = true_pos + true_neg + false_pos + false_neg
          percent_pos = (true_pos + false_neg).to_f/total
          percent_neg = (true_neg + false_pos).to_f/total
          if sens > 0.5 && spec > 0.5
            print "."
            ((sens+ppv+accuracy).to_f/3 - (sens-spec).abs * 0.02)
          else
            print "."
            ((sens+ppv+accuracy).to_f/3 * ([spec, sens].min)**2)
          end
        end
      end
    end
    puts ""
  end
end
