class Patient < ApplicationRecord
  include BitOptimizations
  has_many :labs
  validates_presence_of :pid, :sex, :surgery_time, :dob
  validates_inclusion_of :infection, in: [true, false]
  validates_inclusion_of :sex, in: ["M", "F"]
  validates_uniqueness_of :pid

  # default_scope -> { where.not(infection: nil) }
  scope :infected, -> { where(infection: true) }
  scope :not_infected, -> { where(infection: false) }
  scope :test_data, -> { where(infection: nil) }

  INFECTION_CACHE = 1086206719652250843848216326404574406648231036080188574918671440584348903520231537114490365301618522041459355315624309053790271211673555829493007346292076161650305588356789191107172613227833254499894023307937044700095907193544003532538869703372957400138239099941728064372777
  HEALTHY_CACHE = 3241582079411118854270151191631529633954166258807718934353582687762163706224458511699935794930069161191713288469138089083613919995772444091663407965276324852383198126963060458403075979577452150606480492676129010706684740580676790232025277691326605415264060954772541617995734
  ALL_CACHE = 4327788799063369698118367518036104040602397294887907509272254128346512609744690048814426160231687683233172643784762398137404191207445999921156415311568401014033503715319849649510248592805285405106374515984066055406780647774220793764564147394699562815402300054714269682368511

  def self.all_cache
    ALL_CACHE
  end

  def self.has_assessment?(patient_id)
    true_bit?(ALL_CACHE, patient_id)
  end

  def self.cache_infections
    cache_array_of_ids(infected.pluck(:id))
  end

  def self.cache_healthy
    cache_array_of_ids(not_infected.pluck(:id))
  end

  def self.cache_all_patients
    cache_array_of_ids(all.pluck(:id))
  end

  def self.infected?(patient_id)
    true_bit?(INFECTION_CACHE, patient_id)
  end

  def self.assess_dx(dx_cache)
    true_pos = (INFECTION_CACHE & dx_cache).to_s(2).count("1")
    false_pos = (INFECTION_CACHE ^ dx_cache).to_s(2).count("1")
    false_neg = infected.count - true_pos
    true_neg = not_infected.count - false_pos
    return { true_positive: true_pos, true_negative: true_neg, false_positive: false_pos, false_negative: false_neg }
  end

  def self.patient_ids
    pluck(:id)
  end

  def self.male_cache
    cache_array_of_ids(where(sex: "M").pluck(:id))
  end

  def self.female_cache
    cache_array_of_ids(where(sex: "F").pluck(:id))
  end

end
