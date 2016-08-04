class RemoveStupidCachesFromLabTypes < ActiveRecord::Migration[5.0]
  def self.up
    remove_column :lab_types, :patient_cache
    remove_column :lab_types, :infect_cache
    remove_column :lab_types, :infection_cache

    add_column :lab_types, :patient_cache, :string
  end

  def self.down
    remove_column :lab_types, :patient_cache
    add_column :lab_types, :infect_cache, :string
    add_column :lab_types, :patient_cache, :hstore
    add_column :lab_types, :infection_cache, :hstore
  end
end
