class BackfillBlankBallotNames < ActiveRecord::Migration[8.0]
  # Ballots created by the election editor / CSV import saved with a blank name.
  # Backfill the logical label; `full_name` returns the composed name when blank.
  def up
    Ballot.reset_column_information
    Ballot.where(name: [nil, '']).find_each do |ballot|
      ballot.update_columns(name: ballot.full_name) # rubocop:disable Rails/SkipsModelValidations
    end
  end

  def down
    # No-op: names are derived, nothing to revert.
  end
end
