class AddMaxMinToLabTypes < ActiveRecord::Migration[5.0]
  def self.up
    add_column :lab_types, :val_max, :decimal
    add_column :lab_types, :val_min, :decimal
    add_column :lab_types, :hours_max, :decimal
    add_column :lab_types, :hours_min, :decimal

    LabType.all.each do |lab_type|
      lab_type.val_max = lab_type.labs.maximum(:value)
      lab_type.val_min = lab_type.labs.minimum(:value)
      lab_type.hours_max = lab_type.labs.maximum(:hours_after_surgery)
      lab_type.hours_min = lab_type.labs.minimum(:hours_after_surgery)
      lab_type.save!
    end

    change_column_null :lab_types, :val_max, false
    change_column_null :lab_types, :val_min, false
    change_column_null :lab_types, :hours_max, false
    change_column_null :lab_types, :hours_min, false
  end

  def self.down
    remove_column :lab_types, :val_max
    remove_column :lab_types, :val_min
    remove_column :lab_types, :hours_max
    remove_column :lab_types, :hours_min
  end
end
