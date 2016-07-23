class Gene < ApplicationRecord
  has_and_belongs_to_many :codons

  def fitness
    fitness || evaluate_fitness!
  end

private

  def evaluate_fitness
    codons.each do |codon|
    end
  end

  def evaluate_codon(codon)
    range_start = codon.range_start
    range_end = codon.range_end
    if range_start >= 0 && range_end >= 0
      [range_start, range_end]
    elsif range_start < 0 && range_end < 0
      [range_start, range_end]
    elsif range_start < 0 && range_end >= 0
      :|
    elsif range_start >= 0 && range_end < 0
      :&
    end
  end

  def range_proc(range_start, range_end, patient_id)
    if range_start < range_end
      lam = lambda do |range_start, range_end|
        Patient.find(patient_id).labs.last
      end
    end
  end

end
