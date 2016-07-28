class Codon < ApplicationRecord
  belongs_to :lab_type
  belongs_to :value_start, class_name: :Lab, foreign_key: :value_start_id
  belongs_to :value_end, class_name: :Lab, foreign_key: :value_end_id
  belongs_to :date_start, class_name: :Lab, foreign_key: :date_start_id
  belongs_to :date_end, class_name: :Lab, foreign_key: :date_end_id

  validates :lab_type, presence: true
  validates_presence_of :value_start
  validates_presence_of :value_end
  validates_presence_of :date_start
  validates_presence_of :date_end
  validates_uniqueness_of :value_start, scope: [:value_end, :date_start, :date_end, :lab_type]

  scope :by_fitness, -> { where.not(fitness: nil).order(fitness: :desc)}

  before_validation do |codon|
    codon.lab_type ||= LabType.by_number_of_patients.first
    max_value = codon.lab_type.number_of_labs
    values = [Random.rand(max_value), Random.rand(max_value)].sort
    dates = [Random.rand(max_value), Random.rand(max_value)].sort

    unless codon.value_start && codon.value_end
      labs = lab_type.labs.by_value
      codon.value_start ||= labs[values.first]
      codon.value_end ||= labs[values.last]
    end

    unless codon.date_start && codon.date_end
      labs = lab_type.labs.by_hours
      codon.date_start ||= labs[dates.first]
      codon.date_end ||= labs[dates.last]
    end
  end

  after_create do |codon|
    codon.evaluate!
  end

  def self.purge_invalid!
    all.each { |c| c.destroy if c.invalid? }
  end

  def start_value
    value_start.value
  end

  def end_value
    value_end.value
  end

  def start_hours
    date_start.hours_after_surgery
  end

  def end_hours
    date_end.hours_after_surgery
  end

  def sensitivity
    return 0 if (true_positive + false_negative) == 0
    true_positive.to_f / (true_positive + false_negative)
  end

  def specificity
    return 0 if (true_negative + false_positive) == 0
    true_negative.to_f / (true_negative + false_positive)
  end

  def ppv
    return 0 if (true_positive + false_positive) == 0
    true_positive.to_f/(true_positive + false_positive)
  end

  def npv
    return 0 if (true_negative + false_negative) == 0
    true_negative.to_f/(true_negative + false_negative)
  end

  def lr_pos
    return 0 if (1.0-specificity) == 0
    sensitivity/(1.0-specificity)
  end

  def lr_neg
    return 0 if specificity == 0
    (1.0-sensitivity)/specificity
  end

  def evaluate!
    true_positive = 0
    false_positive = 0
    false_negative = 0
    true_negative = 0
    lab_type.patient_cache.each do |patient_id, labs_by_id|
      # labs = Lab.where(patient_id: patient_id.to_i, lab_type_id: lab_type_id).where(Lab.arel_table[:hours_after_surgery].gt(start_hours)).where(Lab.arel_table[:hours_after_surgery].lt(end_hours)).pluck(:id).as_json
      lab_higher = Lab.by_value.where(patient_id: patient_id.to_i, lab_type_id: lab_type_id).where(Lab.arel_table[:hours_after_surgery].gteq(end_hours)).limit(1).first
      lab_lower = Lab.by_value.where(patient_id: patient_id.to_i, lab_type_id: lab_type_id).where(Lab.arel_table[:hours_after_surgery].lteq(end_hours)).limit(1).first
      if lab_higher && lab_lower
        avg = (end_hours - lab_higher.hours_after_surgery).abs < (end_hours - lab_lower.hours_after_surgery).abs ? lab_higher.value : lab_lower.value
      elsif lab_higher
        avg = lab_higher.value
      elsif lab_lower
        avg = lab_lower.value
      end
      if avg
        # avg = labs.map {|lab_id| labs_by_id[lab_id.to_s]["value"]}.reduce(:+)/labs.count
        infected = lab_type.infected?(patient_id)
        if avg >= start_value && avg <= end_value
          ddx = true
        else
          ddx = false
        end
        if(ddx == true && infected == true)
          true_positive += 1
        elsif(ddx == true && infected == false)
          false_positive += 1
        elsif(ddx == false && infected == true)
          false_negative += 1
        elsif(ddx == false && infected == false)
          true_negative +=1
        end
      end
    end
    update(true_positive: true_positive, true_negative: true_negative, false_positive: false_positive, false_negative: false_negative)
  end

  def fitness!
    evaluate! unless true_positive && true_negative && false_positive && false_negative
    fitness = yield(true_positive, true_negative, false_positive, false_negative, sensitivity, specificity, ppv, npv, lr_pos, lr_neg)
    update!(fitness: fitness) if valid?
    fitness
  end

end
