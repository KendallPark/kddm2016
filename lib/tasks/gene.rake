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

  task :cullgenes => :environment do
    fittest = Gene.by_fitness.first
    puts fittest.stats
    fittest.update!(gilded: true)
    Gene.where.not(id: fittest.id).delete_all
  end

  task :refit => :environment do
    GenePool.compute_fitness!(Gene.all)
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
    Codon.gilded.by_power.first(count).each { |g| puts g.stats }
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
