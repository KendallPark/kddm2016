class AddInfectionCacheToLabTypes < ActiveRecord::Migration[5.0]
  def self.up
    add_column :lab_types, :infection_cache, :hstore

    LabType.all.each do |lab_type|
      lab_type.cache_infection!
    end
  end

  def self.down
    remove_column :lab_types, :infection_cache
  end
end
