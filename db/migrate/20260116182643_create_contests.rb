class CreateContests < ActiveRecord::Migration[7.2]
  def change
    create_table :contests do |t|
      t.date :date, null: false
      t.string :location, null: false
      t.string :contest_type, null: false
      t.references :office, null: false, foreign_key: true
      t.references :ballot, null: false, foreign_key: true

      t.timestamps
    end
    
    add_index :contests, [:date, :location, :office_id, :ballot_id], unique: true, name: 'index_contests_unique'
    add_index :contests, :date
    add_index :contests, :contest_type
  end
end
