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

ActiveRecord::Schema[7.2].define(version: 2026_02_03_004252) do
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
    t.index ["date"], name: "index_ballots_on_date"
    t.index ["state", "date", "election_type"], name: "index_ballots_unique", unique: true
  end

  create_table "candidates", force: :cascade do |t|
    t.bigint "person_id", null: false
    t.bigint "contest_id", null: false
    t.string "outcome", null: false
    t.integer "tally", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["contest_id"], name: "index_candidates_on_contest_id"
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
    t.index ["branch"], name: "index_offices_on_branch"
    t.index ["district_id"], name: "index_offices_on_district_id"
    t.index ["level"], name: "index_offices_on_level"
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
    t.index ["first_name", "last_name"], name: "index_people_on_first_name_and_last_name"
    t.index ["party_affiliation_id"], name: "index_people_on_party_affiliation_id"
    t.index ["state_of_residence"], name: "index_people_on_state_of_residence"
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
end
