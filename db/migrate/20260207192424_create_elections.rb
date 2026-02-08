class CreateElections < ActiveRecord::Migration[8.0]
  def change
    create_table :elections do |t|
      t.string :state
      t.date :date
      t.string :election_type
      t.integer :year
      t.date :registration_deadline
      t.date :early_voting_start
      t.date :early_voting_end
      t.string :name

      t.timestamps
    end
  end
end
