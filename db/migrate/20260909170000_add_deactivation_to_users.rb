class AddDeactivationToUsers < ActiveRecord::Migration[8.0]
  def change
    # Soft state, deliberately not a delete: researchers come in cohorts that
    # finish, but their work stays attributed to them forever
    # (social_media_accounts.entered_by, demographic_verifications.verified_by,
    # PaperTrail whodunnit). Deleting a graduated researcher would either
    # orphan or erase that attribution.
    #
    # A nullable timestamp rather than a boolean: when someone lost access is
    # the question people actually ask.
    add_column :users, :deactivated_at, :datetime
    add_reference :users, :deactivated_by, foreign_key: { to_table: :users }
    add_column :users, :cohort, :string

    add_index :users, :deactivated_at
    add_index :users, :cohort
  end
end
