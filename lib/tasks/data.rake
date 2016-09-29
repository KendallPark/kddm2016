require 'csv'

namespace :data do

  task :patients => :environment do
    patient_data_path = Rails.root.join("data", "private", "WoundInf_Eval_noLabel.csv")
    patient_csv = CSV.open(patient_data_path, headers: true, converters: [:numeric, :date_time])
    patient_csv.each do |patient_row|
      patient_hash = patient_row.to_h
      patient = Patient.new do |t|
        t.pid = patient_hash["PID"]
        # binding.pry unless patient_hash["Infection"]
        t.infection = nil
        surgery_time = patient_hash["t.IndexSurgery"]
        t.surgery_time = surgery_time
        t.infection_time = patient_hash["t.Infection"].is_a?(DateTime) ? patient_hash["t.Infection"] : nil
        t.sex = patient_hash["Sex"]
        dob = DateTime.new(patient_hash["YoB"], 1, 1)
        t.dob = dob
        t.age_at_surgery = ((surgery_time.to_date - dob)/(Time.days_in_year)).to_f
      end
      begin
        # binding.pry
        patient.save!
      rescue ActiveRecord::RecordInvalid
        binding.pry
      end
    end
  end

  task :labs => :environment do
    lab_names = {}
    lab_names_path = Rails.root.join("data", "private", "uniqueTestTypes-translation.csv")
    lab_names_csv = CSV.open(lab_names_path, headers: true)
    lab_names_csv.each do |name_row|
      lab_names[name_row["TestType"]] = name_row["TestTypeTranslation"]
    end

    lab_data_path = Rails.root.join("data", "private", "WoundInf_Eval_Tests_Formatted_Date.csv")

    @fz = FuzzyMatch.new(lab_names.keys)

    def fuzzy_match(name)
      @fz.find(name)
    end

    lab_csv = CSV.open(lab_data_path, headers: true, converters: [:numeric, :date_time])
    lab_csv.each_with_index do |lab_row, i|
      lab_hash = lab_row.to_h
      lab = Lab.new do |t|
        patient = Patient.unscoped.find_by(pid: lab_hash["PID"])
        t.pid = lab_hash["PID"]
        t.patient = patient
        t.name_original = lab_hash["TestType"]
        if lab_names[lab_hash["TestType"]]
          t.name = lab_names[lab_hash["TestType"]]
        else
          t.name = lab_names[fuzzy_match(lab_hash["TestType"])]
          t.fuzzy_name = true
        end
        lab_type = LabType.find_by(name: t.name)
        binding.pry unless lab_type
        t.lab_type_id = lab_type.id
        t.value_original = lab_hash["Answer"]
        t.value = lab_hash["NumAnswer"]
        t.qualifier = lab_hash["answerQualifier"]
        t.date = lab_hash["formattedDate"]
        t.hours_after_surgery = (t.date - patient.surgery_time) / 3600
        t.test_data = true
      end
      begin
        # binding.pry
        next if lab.invalid? && lab.errors.messages[:pid]
        lab.save!
        printf "\r#{i}/65535 labs saved.", i
      rescue ActiveRecord::RecordInvalid
        binding.pry
      end
    end
    binding.pry
  end

end
