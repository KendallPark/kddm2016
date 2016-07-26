class Gene < ApplicationRecord
  has_and_belongs_to_many :codons

  def fitness
    fitness || evaluate_fitness!
  end

private

  def evaluate_fitness!
    fitness = 0
    codons.each do |codon|
      codon.fitness! do |t_pos, t_neg, f_pos, f_neg|
        fitness += yield(t_pos, t_neg, f_pos, f_neg)
      end
    end
  end

end
