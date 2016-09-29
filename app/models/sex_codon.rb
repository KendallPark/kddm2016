class SexCodon < Codon

  before_validation do |codon|
    codon.lab_type = LabType.find_by_name("sex")

    male_or_female
    codon.val_start = Random.rand((lab_type.val_min-(lab_type.val_max-lab_type.val_min)*0.25).to_f..(lab_type.val_max+(lab_type.val_max-lab_type.val_min)*0.25).to_f)
    codon.val_end = Random.rand((lab_type.val_min-(lab_type.val_max-lab_type.val_min)*0.25).to_f..(lab_type.val_max+(lab_type.val_max-lab_type.val_min)*0.25).to_f)

    codon.hours_after_surgery ||= VALID_HOURS.sample

    codon.threshold ||= Random.rand
  end

  def evaluate!
    update!(true_positive: 0,
            true_negative: 0,
            false_positive: 0,
            false_negative: 0,
            dx_cache: Patient.male_cache,
            ever_cache: Patient.male_cache,
            crossing_cache: Patient.male_cache,
            ratio_cache: Patient.male_cache)
  end

end
