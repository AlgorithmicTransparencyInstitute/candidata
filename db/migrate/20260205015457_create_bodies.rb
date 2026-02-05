class CreateBodies < ActiveRecord::Migration[7.2]
  def change
    create_table :bodies do |t|
      t.string :name, null: false
      t.string :level
      t.string :branch
      t.string :state
      t.string :country, default: 'US'
      t.string :jurisdiction
      t.string :jurisdiction_ocdid
      t.string :chamber_type
      t.integer :parent_body_id
      t.integer :seats_count
      t.date :founded_date
      t.string :website

      t.timestamps
    end
    add_index :bodies, :name
    add_index :bodies, :state
    add_index :bodies, :country
    add_index :bodies, :level
    add_index :bodies, :parent_body_id
    add_index :bodies, [:name, :country], unique: true
  end
end
