class AddJunkipediaFieldsToSocialMediaAccounts < ActiveRecord::Migration[8.0]
  def change
    add_column :social_media_accounts, :junkipedia_channel_id, :string
    add_column :social_media_accounts, :junkipedia_enqueued_at, :datetime
    add_column :social_media_accounts, :junkipedia_id_collected_at, :datetime
    add_column :social_media_accounts, :junkipedia_last_error, :text

    add_index :social_media_accounts, :junkipedia_channel_id
    add_index :social_media_accounts, :junkipedia_enqueued_at
  end
end
