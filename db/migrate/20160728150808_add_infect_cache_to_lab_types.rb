class AddInfectCacheToLabTypes < ActiveRecord::Migration[5.0]
  def self.up
    add_column :lab_types, :infect_cache, :string
    LabType.in_batches(of: 100) do |lab_types|
      cache = 0
      lab_types.each do |lab_type|
        lab_type.infect_cache = LabType.cache(lab_type.infection_cache)
        lab_type.save!
      end
    end
  end

  def self.down
    remove_column :lab_types, :infect_cache
  end
end
