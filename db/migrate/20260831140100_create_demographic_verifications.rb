class CreateDemographicVerifications < ActiveRecord::Migration[8.0]
  def change
    # One row per person+field: the evidence trail behind a demographic claim.
    # Kept out of `people` because the point of this table is auditability —
    # who determined this, when, from what source, and whether they could
    # determine it at all.
    create_table :demographic_verifications do |t|
      t.references :person, null: false, foreign_key: true
      t.string :field_key, null: false
      t.string :status, null: false, default: 'verified'
      t.string :value_snapshot
      t.string :source_url
      t.text   :notes
      t.references :verified_by, foreign_key: { to_table: :users }
      t.datetime :verified_at
      t.references :assignment, foreign_key: true

      t.timestamps
    end

    add_index :demographic_verifications, [:person_id, :field_key], unique: true
    add_index :demographic_verifications, :status
  end
end
