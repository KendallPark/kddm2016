class Patient < ApplicationRecord
  has_many :labs
  validates_presence_of :pid, :sex, :surgery_time, :dob
  validates_inclusion_of :infection, in: [true, false]
  validates_inclusion_of :sex, in: ["M", "F"]

  scope :infected, -> { where(infection: true) }
  scope :not_infected, -> { where(infection: false) }
end
