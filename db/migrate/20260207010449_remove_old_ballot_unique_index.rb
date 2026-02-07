class RemoveOldBallotUniqueIndex < ActiveRecord::Migration[8.0]
  def change
    # Remove the old unique index that doesn't include party
    # This index prevents multiple primaries (Democratic, Republican) in the same state/year
    # We keep the newer index (index_ballots_unique_with_party) which includes party
    remove_index :ballots, name: 'index_ballots_on_state_and_year_and_election_type'
  end
end
