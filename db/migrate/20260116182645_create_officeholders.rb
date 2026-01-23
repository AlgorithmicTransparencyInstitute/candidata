class CreateOfficeholders < ActiveRecord::Migration[7.2]
  def change
    create_table :officeholders do |t|
      t.references :person, null: false, foreign_key: true
      t.references :office, null: false, foreign_key: true
      t.date :start_date, null: false
      t.date :end_date

      t.timestamps
    end
    
    add_index :officeholders, [:person_id, :office_id, :start_date], unique: true, name: 'index_officeholders_unique'
    add_index :officeholders, :start_date
    add_index :officeholders, :end_date
  end
end
