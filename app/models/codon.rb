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

  scope :by_fitness, -> { order(fitness: :desc)}

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
    return 0 if (true_positive + false_positive) == 0
    true_positive.to_f / (true_positive + false_positive)
  end

  def specificity
    return 0 if (false_negative + true_negative) == 0
    true_negative.to_f / (false_negative + true_negative)
  end

  def evaluate!
    true_positive = 0
    false_positive = 0
    false_negative = 0
    true_negative = 0
    lab_type.patient_cache.each do |patient_id, labs_by_id|
      labs = Lab.where(patient_id: patient_id.to_i, lab_type_id: lab_type_id).where(Lab.arel_table[:hours_after_surgery].gt(start_hours)).where(Lab.arel_table[:hours_after_surgery].lt(end_hours)).pluck(:id).as_json
      unless labs.empty?
        avg = labs.map {|lab_id| labs_by_id[lab_id.to_s]["value"]}.reduce(:+)/labs.count
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
    fitness = yield(true_positive, true_negative, false_positive, false_negative, sensitivity, specificity)
    update!(fitness: fitness)
    fitness
  end

end
