class AddOutlierToLabs < ActiveRecord::Migration[5.0]
  def change
    add_column :labs, :outlier, :boolean, default: false
  end
end
