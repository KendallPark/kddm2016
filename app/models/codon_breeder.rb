class CodonBreeder < Breeder
  def mate(codon_1, codon_2)
    lab_type = codon_1.lab_type

    start_vals = [codon_1.val_start, codon_2.val_start].sort
    end_vals = [codon_1.val_end, codon_2.val_end].sort
    hours = [codon_1.hours_after_surgery, codon_2.hours_after_surgery].sort

    value_start = mutate? ? nil : Random.rand(start_vals.first.to_f..start_vals.last.to_f)
    value_end = mutate? ? nil : Random.rand(end_vals.first.to_f..end_vals.last.to_f)
    hours_after_surgery = mutate? ? nil : hours.sample

    baby = Codon.new( lab_type: lab_type,
                      val_start: value_start,
                      val_end: value_end,
                      hours_after_surgery: hours_after_surgery )
  end
end
