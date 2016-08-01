namespace :gene do
  desc "Dumps the database to backups"
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

  desc "something"
  task :refit => :environment do
    pool = AllelePool.new
    Codon.where("updated_at <= ?", 2.hours.ago).in_batches(of: 100) do |codons|
      puts "yay"
      pool.compute_fitness!(codons)
    end
  end

  desc "purge"
  task :purge => :environment do
    Codon.in_batches.each do |codons|
      Codon.transaction do
        codons.each do |codon|
          deleted = codon.delete if codon.invalid?
          puts "#{codon.id} deleted" if deleted
        end
      end
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

  task :reeval => :environment do
    count = Codon.count
    Parallel.each((0..(count/10).ceil), in_threads: 4) do |i|
      ActiveRecord::Base.connection_pool.with_connection do
        Codon.in_batches(of: 10, start: i*10).each do |codons|
          puts "batch #{i*10}/#{count}"
          Codon.transaction do
            codons.each do |codon|
              codon.evaluate!
            end
          end
        end
      end
    end
  end

end
