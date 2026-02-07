class UpdateContestsAndBallotsForPrimaries < ActiveRecord::Migration[8.0]
  def change
    # Make location nullable in contests (not all contests have a specific location)
    change_column_null :contests, :location, true

    # Remove old unique index on ballots
    remove_index :ballots, name: "index_ballots_unique", if_exists: true

    # Add new unique index on ballots including party for primary elections
    add_index :ballots, [:state, :date, :election_type, :party], unique: true, name: "index_ballots_unique_with_party"

    # Add index on party for ballots
    add_index :ballots, :party

    # Add index on party for contests
    add_index :contests, :party
  end
end
