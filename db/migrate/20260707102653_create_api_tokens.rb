class CreateApiTokens < ActiveRecord::Migration[8.0]
  def change
    create_table :api_tokens do |t|
      t.string :name, null: false
      t.string :token_digest, null: false
      t.references :created_by, foreign_key: { to_table: :users }
      t.datetime :last_used_at
      t.datetime :revoked_at

      t.timestamps
    end
    add_index :api_tokens, :token_digest, unique: true
  end
end
