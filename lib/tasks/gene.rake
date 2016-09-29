namespace :gene do

  task :genes => :environment do
    pool = GenePool.new
    puts pool.stats
    200.times do |i|
      puts "Generation: #{i}"
      pool.breed_generations!
      puts pool.stats
    end
    puts pool.stats
  end

  task :trees, [:tree_type] => :environment do |t, args|
    tree_type = args[:tree_type] || "DTreeGene"
    100.times do |j|
      pool = GenePool.new({gene_model: tree_type, selection_size: 15})
      puts pool.stats
      progression = []
      100.times do |i|
        puts "Generation: #{i}"
        pool.refine_fittest!
        puts pool.stats
        # pool.breed_little_ones!
        puts pool.stats
        pool.breed_generations!
        puts pool.stats
        progression << pool.alpha.fitness
        # break if progression.length >= 20 && progression.last(20).uniq.length == 1
        # pool.new_genes!(50)
      end
    end
  end

  task :new_genes => :environment do
    tree_type = "DTreeGene"
    pool = GenePool.new({gene_model: tree_type, selection_size: 15})
    10.times do
      pool.new_genes!
    end
  end

  # task :create_age_labs => :environment do
  #   age_lab = LabType.new(name: "age", )
  #   Patient.each do |patient|
  #
  #   end
  #
  #   Patient.each do |patient|
  #     age_at_surgery = ((patient.surgery_time.to_date  - patient.dob)/(Time.days_in_year)).to_i
  #     patient.labs.create!(name: "age",
  #                          name_original: "age",
  #                          date: patient.surgery_time,
  #                          value_original: age_at_surgery,
  #                          value: age_at_surgery,
  #                          pid: patient.pid,
  #                          lab_type_id: age_lab.id,
  #                          hours_after_surgery: 0)
  # end

  task :add_ages => :environment do
    print "Adding ages"
    lab_type = LabType.find_by(name: "age")
    100.times do
      codon = Codon.new(lab_type_id: lab_type.id)
      codon.evaluate!
      gene = DTreeGene.new
      gene.starting_codon = codon.reload
      gene.save!
      print "."
    end
  end

  task :refittrees => :environment do
    DTreeGene.order(id: :desc).in_batches(of: 100) do |trees|
      GenePool.compute_fitness!(trees)
    end
  end

  task :reevaltrees => :environment do
    # Codon.where("created_at >= ?", 1.hour.ago).order(id: :desc).in_batches(of: 100) do |trees|
    #   trees.each do |tree|
    #     print "."
    #     tree.evaluate!
    #   end
    # end
    DTreeGene.by_fitness.in_batches(of: 100) do |trees|
      trees.each do |tree|
        print "."
        tree.evaluate!
      end
      GenePool.compute_fitness!(trees)
      print "!"
    end
  end

  task :resizetrees => :environment do
    DTreeGene.order(id: :desc).in_batches(of: 100) do |trees|
      trees.each do |tree|
        print "."
        tree.update!(size: tree.gene_size)
      end
    end
  end

  task :top_trees => :environment do
    # GenePool.compute_fitness!(DTreeGene.by_uniq_fitness.first(10000))
    DTreeGene.by_uniq_sig.first(30).each do |t|
      puts "#{t.id} size: #{t.size}  acc: #{t.accuracy.round(4)}  sens: #{t.sensitivity.round(4)}  spec:  #{t.specificity.round(4)}  ppv: #{t.ppv.round(4)}  npv: #{t.npv.round(4)}  fit: #{t.fitness.round(4)}"
    end
  end

  task :add_gilded => :environment do
    print "Adding gilded"
    10.times do
      Codon.top_gilded_uniq.sort{|a , b| ((b.true_positive + b.true_negative)*b.fitness) <=> ((a.true_positive + a.true_negative)*a.fitness) }.each do |codon|
        # codon.evaluate!
        gene = DTreeGene.new
        gene.starting_codon = codon.reload
        gene.save!
        print "."
      end
    end
  end

  task :gild_trees => :environment do
    Codon.top_gilded_uniq.each do |codon|
      gene = TreeGene.new
      gene.sequence = { tree: gene.codon_cache(codon) }
      gene.save!
    end
  end

  task :cullgenes => :environment do
    fittest = Gene.by_fitness.first
    puts fittest.stats
    fittest.update!(gilded: true)
    Gene.where.not(id: fittest.id).delete_all
  end

  task :culltrees => :environment do
    fittest = DTreeGene.by_fitness.first
    puts fittest.stats
    fittest.update!(gilded: true)
    DTreeGene.where.not(id: fittest.id).delete_all
  end

  task :refit => :environment do
    GenePool.compute_fitness!(Gene.all)
  end

  task :refittree => :environment do
    GenePool.compute_fitness!(TreeGene.all)
  end



  task :codons, [:index] => :environment do |t, args|
    index = (args[:index] || 0).to_i
    (index...200).each do |i|
      puts "Index: #{i}"
      pool = AllelePool.new({lab_index: i})
      8.times do
        puts pool.stats
        pool.breed_generations!
      end
      puts pool.stats
    end
  end

  task :gild, [:codon_id] => :environment do |t, args|
    codon_id = args[:codon_id]
    Codon.find(codon_id).update!(gilded: true)
  end

  task :codon, [:index] => :environment do |t, args|
    index = args[:index].to_i || 0
    pool = AllelePool.new({lab_index: index})
    5.times do
      puts pool.stats
      pool.breed_generations!
    end
    puts pool.stats
  end

  namespace :purge do
    task :invalid => :environment do
      Codon.in_batches.each do |codons|
        Codon.transaction do
          codons.each do |codon|
            deleted = codon.delete if codon.invalid?
            puts "#{codon.id} deleted" if deleted
          end
        end
      end
    end

    task :bad_dates => :environment do
      Codon.unscoped.where("hours_after_surgery >= ?", 0).delete_all
    end
  end

  task :shun_outliers => :environment do
    outliers = Lab.where(value: -999).update(outlier: true)
    outliers.pluck(:lab_type_id).uniq.each { |id| LabType.find(id).update_min_max! }
  end

  task :cull => :environment do
    LabType.in_batches(of: 10).each do |lab_types|
      lab_types.each do |lab_type|
        fittest = lab_type.codons.by_fitness.first
        next unless fittest
        puts fittest.stats
        fittest.update!(gilded: true)
        lab_type.codons.where.not(id: fittest.id).delete_all
      end
    end
  end

  task :top_gilded, [:count] => :environment do |t, args|
    count = (args[:count] || "10").to_i
    Codon.top_gilded_uniq.sort{|a , b| ((b.true_positive + b.true_negative)*b.fitness) <=> ((a.true_positive + a.true_negative)*a.fitness) }.first(count).each { |g| puts g.stats }
  end

  namespace :reeval do
    task :lab_types => :environment do
      puts "Reevaluating LabTypes"
      LabType.in_batches(of: 100) do |lab_types|
        lab_types.each do |lab_type|
          print "."
          lab_type.reload.update_everything!
        end
      end
      puts ""
    end

    task :fitness => :environment do
      puts "Reevaluating Fitness"
      Codon.unscoped.in_batches(of: 100) do |codons|
        AllelePool.compute_fitness!(codons)
      end
    end

    task :codons => :environment do
      puts "Reevaluating Codons"
      Codon.unscoped.in_batches(of: 10).each do |codons|
        codons.each do |codon|
          print "."
          codon.evaluate!
        end
      end
      puts ""
    end

  end

end
