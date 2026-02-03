# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.2].define(version: 2026_02_03_031237) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "ballots", force: :cascade do |t|
    t.string "state", null: false
    t.date "date", null: false
    t.string "election_type", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "year"
    t.string "name"
    t.index ["date"], name: "index_ballots_on_date"
    t.index ["state", "date", "election_type"], name: "index_ballots_unique", unique: true
    t.index ["state", "year", "election_type"], name: "index_ballots_on_state_and_year_and_election_type", unique: true
    t.index ["year"], name: "index_ballots_on_year"
  end

  create_table "candidates", force: :cascade do |t|
    t.bigint "person_id", null: false
    t.bigint "contest_id", null: false
    t.string "outcome", null: false
    t.integer "tally", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "party_at_time"
    t.boolean "incumbent", default: false
    t.string "airtable_id"
    t.index ["airtable_id"], name: "index_candidates_on_airtable_id", unique: true
    t.index ["contest_id"], name: "index_candidates_on_contest_id"
    t.index ["incumbent"], name: "index_candidates_on_incumbent"
    t.index ["outcome"], name: "index_candidates_on_outcome"
    t.index ["person_id", "contest_id"], name: "index_candidates_unique", unique: true
    t.index ["person_id"], name: "index_candidates_on_person_id"
  end

  create_table "contests", force: :cascade do |t|
    t.date "date", null: false
    t.string "location", null: false
    t.string "contest_type", null: false
    t.bigint "office_id", null: false
    t.bigint "ballot_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ballot_id"], name: "index_contests_on_ballot_id"
    t.index ["contest_type"], name: "index_contests_on_contest_type"
    t.index ["date", "location", "office_id", "ballot_id"], name: "index_contests_unique", unique: true
    t.index ["date"], name: "index_contests_on_date"
    t.index ["office_id"], name: "index_contests_on_office_id"
  end

  create_table "districts", force: :cascade do |t|
    t.string "state", null: false
    t.integer "district_number"
    t.string "level", null: false
    t.text "boundaries"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["state", "district_number", "level"], name: "index_districts_unique", unique: true
    t.index ["state"], name: "index_districts_on_state"
  end

  create_table "officeholders", force: :cascade do |t|
    t.bigint "person_id", null: false
    t.bigint "office_id", null: false
    t.date "start_date", null: false
    t.date "end_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "elected_year"
    t.boolean "appointed", default: false
    t.string "airtable_id"
    t.index ["airtable_id"], name: "index_officeholders_on_airtable_id", unique: true
    t.index ["elected_year"], name: "index_officeholders_on_elected_year"
    t.index ["end_date"], name: "index_officeholders_on_end_date"
    t.index ["office_id"], name: "index_officeholders_on_office_id"
    t.index ["person_id", "office_id", "start_date"], name: "index_officeholders_unique", unique: true
    t.index ["person_id"], name: "index_officeholders_on_person_id"
    t.index ["start_date"], name: "index_officeholders_on_start_date"
  end

  create_table "offices", force: :cascade do |t|
    t.string "title", null: false
    t.string "level", null: false
    t.string "branch", null: false
    t.string "state"
    t.bigint "district_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "office_category"
    t.string "body_name"
    t.string "seat"
    t.string "role"
    t.string "jurisdiction"
    t.string "jurisdiction_ocdid"
    t.string "ocdid"
    t.string "airtable_id"
    t.index ["airtable_id"], name: "index_offices_on_airtable_id", unique: true
    t.index ["body_name"], name: "index_offices_on_body_name"
    t.index ["branch"], name: "index_offices_on_branch"
    t.index ["district_id"], name: "index_offices_on_district_id"
    t.index ["level"], name: "index_offices_on_level"
    t.index ["ocdid"], name: "index_offices_on_ocdid"
    t.index ["office_category"], name: "index_offices_on_office_category"
    t.index ["role"], name: "index_offices_on_role"
    t.index ["title", "level", "state", "district_id"], name: "index_offices_unique", unique: true
  end

  create_table "parties", force: :cascade do |t|
    t.string "name", null: false
    t.string "abbreviation", null: false
    t.string "ideology"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["abbreviation"], name: "index_parties_on_abbreviation", unique: true
    t.index ["name"], name: "index_parties_on_name", unique: true
  end

  create_table "people", force: :cascade do |t|
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.bigint "party_affiliation_id"
    t.date "birth_date"
    t.date "death_date"
    t.string "state_of_residence"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "person_uuid"
    t.string "middle_name"
    t.string "suffix"
    t.string "gender"
    t.string "race"
    t.string "photo_url"
    t.string "website_official"
    t.string "website_campaign"
    t.string "website_personal"
    t.string "airtable_id"
    t.index ["airtable_id"], name: "index_people_on_airtable_id", unique: true
    t.index ["first_name", "last_name"], name: "index_people_on_first_name_and_last_name"
    t.index ["party_affiliation_id"], name: "index_people_on_party_affiliation_id"
    t.index ["person_uuid"], name: "index_people_on_person_uuid", unique: true
    t.index ["state_of_residence"], name: "index_people_on_state_of_residence"
  end

  create_table "person_parties", force: :cascade do |t|
    t.bigint "person_id", null: false
    t.bigint "party_id", null: false
    t.boolean "is_primary", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["party_id"], name: "index_person_parties_on_party_id"
    t.index ["person_id", "is_primary"], name: "index_person_parties_one_primary", unique: true, where: "(is_primary = true)"
    t.index ["person_id", "party_id"], name: "index_person_parties_on_person_id_and_party_id", unique: true
    t.index ["person_id"], name: "index_person_parties_on_person_id"
  end

  create_table "social_media_accounts", force: :cascade do |t|
    t.bigint "person_id", null: false
    t.string "platform", null: false
    t.string "channel_type"
    t.string "url"
    t.string "handle"
    t.string "status"
    t.boolean "verified", default: false
    t.boolean "account_inactive", default: false
    t.string "airtable_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["airtable_id"], name: "index_social_media_accounts_on_airtable_id", unique: true
    t.index ["channel_type"], name: "index_social_media_accounts_on_channel_type"
    t.index ["person_id", "platform", "handle"], name: "idx_social_accounts_unique", unique: true
    t.index ["person_id"], name: "index_social_media_accounts_on_person_id"
    t.index ["platform"], name: "index_social_media_accounts_on_platform"
  end

  create_table "states", force: :cascade do |t|
    t.string "name", null: false
    t.string "abbreviation", null: false
    t.string "fips_code"
    t.string "state_type", default: "state"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["abbreviation"], name: "index_states_on_abbreviation", unique: true
    t.index ["fips_code"], name: "index_states_on_fips_code", unique: true
    t.index ["name"], name: "index_states_on_name", unique: true
  end

  create_table "temp_accounts", force: :cascade do |t|
    t.string "source_type"
    t.string "url"
    t.string "platform"
    t.string "channel_type"
    t.string "status"
    t.string "state"
    t.string "office_name"
    t.string "level"
    t.string "office_category"
    t.string "people_name"
    t.string "party_roll_up"
    t.boolean "account_inactive"
    t.boolean "verified"
    t.text "raw_data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["channel_type"], name: "index_temp_accounts_on_channel_type"
    t.index ["platform"], name: "index_temp_accounts_on_platform"
    t.index ["source_type"], name: "index_temp_accounts_on_source_type"
    t.index ["state"], name: "index_temp_accounts_on_state"
  end

  create_table "temp_people", force: :cascade do |t|
    t.string "source_type"
    t.string "official_name"
    t.string "state"
    t.string "level"
    t.string "role"
    t.string "jurisdiction"
    t.string "jurisdiction_ocdid"
    t.string "electoral_district"
    t.string "electoral_district_ocdid"
    t.string "office_uuid"
    t.string "office_name"
    t.string "seat"
    t.string "office_category"
    t.string "body_name"
    t.string "person_uuid"
    t.string "registered_political_party"
    t.string "race"
    t.string "gender"
    t.string "photo_url"
    t.string "website_official"
    t.string "website_campaign"
    t.string "website_personal"
    t.string "candidate_uuid"
    t.boolean "incumbent"
    t.boolean "is_2024_candidate"
    t.boolean "is_2024_office_holder"
    t.string "general_election_winner"
    t.string "party_roll_up"
    t.text "raw_data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["level"], name: "index_temp_people_on_level"
    t.index ["office_category"], name: "index_temp_people_on_office_category"
    t.index ["person_uuid"], name: "index_temp_people_on_person_uuid"
    t.index ["registered_political_party"], name: "index_temp_people_on_registered_political_party"
    t.index ["source_type"], name: "index_temp_people_on_source_type"
    t.index ["state"], name: "index_temp_people_on_state"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.string "provider"
    t.string "uid"
    t.string "name"
    t.string "avatar_url"
    t.string "role", default: "researcher_assistant"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["provider", "uid"], name: "index_users_on_provider_and_uid", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "candidates", "contests"
  add_foreign_key "candidates", "people"
  add_foreign_key "contests", "ballots"
  add_foreign_key "contests", "offices"
  add_foreign_key "officeholders", "offices"
  add_foreign_key "officeholders", "people"
  add_foreign_key "offices", "districts"
  add_foreign_key "people", "parties", column: "party_affiliation_id"
  add_foreign_key "person_parties", "parties"
  add_foreign_key "person_parties", "people"
  add_foreign_key "social_media_accounts", "people"
end
