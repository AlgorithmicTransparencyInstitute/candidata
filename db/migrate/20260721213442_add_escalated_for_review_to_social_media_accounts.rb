class AddEscalatedForReviewToSocialMediaAccounts < ActiveRecord::Migration[8.0]
  def change
    # "Escalate for review": a researcher/verifier flags an account they can't
    # make a determination on (usually with notes); admins will later work a
    # list of escalated accounts and decide. Distinct from account_inactive
    # (account exists but was deactivated on the platform).
    add_column :social_media_accounts, :escalated_for_review, :boolean, default: false, null: false
    add_column :social_media_accounts, :escalated_at, :datetime
    add_reference :social_media_accounts, :escalated_by, foreign_key: { to_table: :users }

    add_index :social_media_accounts, :escalated_for_review, where: "escalated_for_review", name: "index_sma_on_escalated_for_review"
  end
end
