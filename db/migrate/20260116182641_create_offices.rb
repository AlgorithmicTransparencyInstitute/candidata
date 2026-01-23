class CreateOffices < ActiveRecord::Migration[7.2]
  def change
    create_table :offices do |t|
      t.string :title, null: false
      t.string :level, null: false
      t.string :branch, null: false
      t.string :state
      t.references :district, foreign_key: true

      t.timestamps
    end
    
    add_index :offices, [:title, :level, :state, :district_id], unique: true, name: 'index_offices_unique'
    add_index :offices, :level
    add_index :offices, :branch
  end
end
