class Patient < ApplicationRecord
  include BitOptimizations
  has_many :labs
  validates_presence_of :pid, :sex, :surgery_time, :dob
  validates_inclusion_of :infection, in: [true, false]
  validates_inclusion_of :sex, in: ["M", "F"]

  scope :infected, -> { where(infection: true) }
  scope :not_infected, -> { where(infection: false) }

  INFECTION_CACHE = 1086206719652250843848216326404574406648231036080188574918671440584348903520231537114490365301618522041459355315624309053790271211673555829493007346292076161650305588356789191107172613227833254499894023307937044700095907193544003532538869703372957400138239099941728064372777

  def self.cache_infections
    cache_array_of_ids(infected.pluck(:id))
  end

  def self.infected?(patient_id)
    true_bit?(INFECTION_CACHE, patient_id)
  end

  def self.assess_dx(dx_cache)
    true_pos = (INFECTION_CACHE & dx_cache).to_s(2).count("1")
    false_pos = ((INFECTION_CACHE | dx_cache) - dx_cache).to_s(2).count("1")
  end

  def self.patient_ids
    pluck(:id)
  end

end
