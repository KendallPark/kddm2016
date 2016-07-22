# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: 'Star Wars' }, { name: 'Lord of the Rings' }])
#   Character.create(name: 'Luke', movie: movies.first)
require 'csv'

# CSV::Converters[:mmddyy] = lambda do |date|
#   begin
#     Date.strptime(date, '%m/%d/%y')
#   rescue ArgumentError
#     date
#   end
# end

patient_data_path = Rails.root.join("data", "private", "WoundInf_Train_Labels.csv")
patient_csv = CSV.open(patient_data_path, headers: true, converters: [:numeric, :date_time])
patient_csv.each do |patient_row|
  patient_hash = patient_row.to_h
  patient = Patient.create do |t|
    t.pid = patient_hash["PID"]
    binding.pry unless patient_hash["Infection"]
    t.infection = patient_hash["Infection"] != 0
    t.surgery_time = patient_hash["t.IndexSurgery"]
    t.infection_time = patient_hash["t.Infection"].is_a?(DateTime) ? patient_hash["t.Infection"] : nil
    t.sex = patient_hash["Sex"]
    t.dob = DateTime.new(patient_hash["YoB"], 1, 1)
  end
  begin
    patient.save!
  rescue ActiveRecord::RecordInvalid
    binding.pry
  end
end

lab_names = {}
lab_names_path = Rails.root.join("data", "private", "uniqueTestTypes-translation.csv")
lab_names_csv = CSV.open(lab_names_path, headers: true)
lab_names_csv.each do |name_row|
  lab_names[name_row["TestType"]] = name_row["TestTypeTranslation"]
end

lab_data_path = Rails.root.join("data", "private", "WoundInf_Train_Tests-cleaned_clean_dates.csv")

@fz = FuzzyMatch.new(lab_names.keys)

def fuzzy_match(name)
  @fz.find(name)
end

lab_csv = CSV.open(lab_data_path, headers: true, converters: [:numeric, :date_time])
lab_csv.each_with_index do |lab_row, i|
  lab_hash = lab_row.to_h
  lab = Lab.create do |t|
    t.pid = lab_hash["PID"]
    t.patient_id = Patient.find_by(pid: lab_hash["PID"]).id
    t.name_original = lab_hash["TestType"]
    if lab_names[lab_hash["TestType"]]
      t.name = lab_names[lab_hash["TestType"]]
    else
      t.name = lab_names[fuzzy_match(lab_hash["TestType"])]
      t.fuzzy_name = true
    end
    t.value_original = lab_hash["Answer"]
    t.value = lab_hash["NumAnswer"]
    t.qualifier = lab_hash["answerQualifier"]
    t.date = lab_hash["formattedDate"]
  end
  begin
    lab.save!
    printf "\r#{i}/65535 labs saved.", i
  rescue ActiveRecord::RecordInvalid
    binding.pry
  end
end
binding.pry
