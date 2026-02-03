class CreateSocialMediaAccounts < ActiveRecord::Migration[7.2]
  def change
    create_table :social_media_accounts do |t|
      t.references :person, null: false, foreign_key: true
      t.string :platform, null: false
      t.string :channel_type
      t.string :url
      t.string :handle
      t.string :status
      t.boolean :verified, default: false
      t.boolean :account_inactive, default: false
      t.string :airtable_id

      t.timestamps
    end

    add_index :social_media_accounts, :platform
    add_index :social_media_accounts, :channel_type
    add_index :social_media_accounts, [:person_id, :platform, :handle], unique: true, name: 'idx_social_accounts_unique'
    add_index :social_media_accounts, :airtable_id, unique: true
  end
end
