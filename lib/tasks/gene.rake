namespace :gene do
  desc "Dumps the database to backups"
  task :codons => :environment do
    Parallel.each((0..200), in_threads: 8) do |i|
      ActiveRecord::Base.connection_pool.with_connection do
        pool = AllelePool.new({lab_index: i})
        5.times do
          puts pool.stats
          pool.breed_generations!
        end
        pool.load_fittest_codons!
        puts pool.stats
      end
    end
  end

  task :codon, [:index] => :environment do |t, args|
    index = args[:index].to_i || 0
    pool = AllelePool.new({lab_index: index})
    5.times do
      puts pool.stats
      pool.breed_generations!
    end
    pool.load_fittest_codons!
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

  task :cull => :environment do
    LabType.in_batches(of: 10).each do |lab_types|
      lab_types.each do |lab_type|
        fittest = lab_type.codons.by_fitness.first
        next unless fittest
        lab_type.codons.where.not(id: fittest.id).delete_all
      end
    end
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
