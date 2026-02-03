class UpdateDistrictsUniqueIndex < ActiveRecord::Migration[7.2]
  def change
    remove_index :districts, name: :index_districts_unique
    add_index :districts, [:state, :district_number, :level, :chamber], 
              unique: true, name: :index_districts_unique
  end
end
