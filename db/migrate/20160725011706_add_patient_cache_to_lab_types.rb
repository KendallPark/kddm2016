class AddPatientCacheToLabTypes < ActiveRecord::Migration[5.0]
  def self.up
    enable_extension "hstore"
    add_column :lab_types, :patient_cache, :hstore

    LabType.all.each do |lab_type|
      lab_type.cache_patients!
    end
  end

  def self.down
    remove_column :lab_types, :patient_cache
    disable_extension "hstore"
  end
end
