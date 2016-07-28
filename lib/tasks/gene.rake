namespace :gene do
  desc "Dumps the database to backups"
  task :codons => :environment do
    Parallel.each((0..200), in_threads: 8) do |i|
      ActiveRecord::Base.connection_pool.with_connection do
        pool = AllelePool.new({lab_index: i})
        pool.load_fittest_codons!
        5.times do
          puts pool.stats
          pool.breed_generations!
        end
        pool.load_fittest_codons!
        puts pool.stats
      end
    end
  end

  desc "something"
  task :refit => :environment do
    pool = AllelePool.new.compute_fitness!(Codon.all)
  end

end
