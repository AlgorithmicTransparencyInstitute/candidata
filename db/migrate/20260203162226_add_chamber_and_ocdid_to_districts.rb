class AddChamberAndOcdidToDistricts < ActiveRecord::Migration[7.2]
  def change
    add_column :districts, :chamber, :string
    add_column :districts, :ocdid, :string
    add_index :districts, :ocdid, unique: true
    add_index :districts, :chamber
  end
end
