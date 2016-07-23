class Codon < ApplicationRecord
  belongs_to :lab_type
  belongs_to :value_start, class_name: :Lab, foreign_key: :value_start_id
  belongs_to :value_end, class_name: :Lab, foreign_key: :value_end_id
  belongs_to :date_start, class_name: :Lab, foreign_key: :date_start_id
  belongs_to :date_end, class_name: :Lab, foreign_key: :date_end_id

  validates :lab_type, presence: true
  validates_presence_of :value_start, :value_end, :date_start, :date_end, skip: :create

  before_create :set_random_values

private

  def set_random_values
    lab_type
  end

end
