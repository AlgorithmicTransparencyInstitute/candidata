class AddWorkflowFieldsToSocialMediaAccounts < ActiveRecord::Migration[7.2]
  def change
    add_reference :social_media_accounts, :entered_by, foreign_key: { to_table: :users }
    add_reference :social_media_accounts, :verified_by, foreign_key: { to_table: :users }
    add_column :social_media_accounts, :entered_at, :datetime
    add_column :social_media_accounts, :verified_at, :datetime
    add_column :social_media_accounts, :research_status, :string, default: 'not_started'
    add_column :social_media_accounts, :verification_notes, :text
    add_column :social_media_accounts, :pre_populated, :boolean, default: false

    add_index :social_media_accounts, :research_status
    add_index :social_media_accounts, :pre_populated
  end
end
