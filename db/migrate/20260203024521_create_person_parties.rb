class CreatePersonParties < ActiveRecord::Migration[7.2]
  def change
    create_table :person_parties do |t|
      t.references :person, null: false, foreign_key: true
      t.references :party, null: false, foreign_key: true
      t.boolean :is_primary, default: false, null: false

      t.timestamps
    end

    add_index :person_parties, [:person_id, :party_id], unique: true
    add_index :person_parties, [:person_id, :is_primary], where: "is_primary = true", unique: true, name: "index_person_parties_one_primary"
  end
end
