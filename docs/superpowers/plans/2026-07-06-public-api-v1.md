# Public Read API (v1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Token-authenticated, read-only public API at `/api/v1/*` so external services can look up and mirror candidates, winners, and current officeholders.

**Architecture:** New `Api::V1::BaseController < ActionController::API` (header-only Bearer auth via a new `ApiToken` model, no sessions/CSRF/Devise) with hand-rolled serializers in a shared module, mirroring the internal `/api` conventions (`{data, meta}` envelope, error codes, pagination shape) but with an independent public contract. Admin UI manages tokens. Spec: `docs/superpowers/specs/2026-07-06-public-api-design.md`.

**Tech Stack:** Rails 8.0.4, Ruby 3.3.6, PostgreSQL, RSpec + FactoryBot request specs, no new gems.

## Global Constraints

- Response envelope: success `{ "data": …, "meta": … }`; errors `{ "error": …, "code": … }` with codes `UNAUTHORIZED` (401), `NOT_FOUND` (404), `INVALID_PARAM` (400), `RATE_LIMITED` (429).
- Pagination on every index: `page` / `per_page`, default 25, **max 500**, stable ordering by `id`.
- All indexes support `updated_since=<ISO8601>` filtering on the resource's own `updated_at`.
- Public payloads expose **verified, active** social accounts only (`verified: true`, `account_inactive: false`) and **no workflow fields** (no `research_status`, `entered_by`, verification metadata, Junkipedia columns).
- Token format `cnd_live_<24 hex chars>`; only the SHA-256 digest is stored; plaintext shown once at creation.
- Rate limit: 300 requests/minute per token.
- `person_uuid` is the public stable identifier for people (numeric ids included for reference).
- Serializers are hand-rolled hashes (repo convention — no serializer gems).
- After all tasks: full suite `bundle exec rspec` green, `bin/rails runner lib/scripts/api_verify.rb` still green (52 checks), new `bin/rails runner lib/scripts/public_api_verify.rb` green.
- Keep commits small, one per task, message style matches repo (imperative, no prefix convention beyond plain description).

---

### Task 1: ApiToken model

**Files:**
- Create: `db/migrate/<timestamp>_create_api_tokens.rb` (via generator)
- Create: `app/models/api_token.rb`
- Test: `spec/models/api_token_spec.rb`

**Interfaces:**
- Produces: `ApiToken.generate!(name:, created_by: nil)` → ApiToken with `#raw_token` reader (plaintext, only in-memory on the freshly created instance); `ApiToken.authenticate(raw) → ApiToken | nil` (nil for blank/unknown/revoked); `#revoke!`; `#revoked?`; `#touch_last_used!` (writes `last_used_at` at most once/minute, no validations/callbacks); scope `ApiToken.active`.

- [ ] **Step 1: Generate the migration**

```bash
bin/rails generate migration CreateApiTokens
```

Replace the generated file's contents with:

```ruby
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
```

- [ ] **Step 2: Run the migration (dev + test)**

```bash
bin/rails db:migrate && bin/rails db:test:prepare
```

Expected: migration runs, `db/schema.rb` gains `api_tokens`.

- [ ] **Step 3: Write the failing model spec**

Create `spec/models/api_token_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe ApiToken, type: :model do
  describe ".generate!" do
    it "creates a token with the cnd_live_ prefix and exposes the plaintext once" do
      token = ApiToken.generate!(name: "test-service")

      expect(token).to be_persisted
      expect(token.raw_token).to match(/\Acnd_live_\h{24}\z/)
      expect(token.token_digest).to eq(Digest::SHA256.hexdigest(token.raw_token))
      # plaintext is never stored
      expect(token.reload.attributes.values).not_to include(token.raw_token)
    end

    it "records the creating user" do
      admin = create(:user, :admin)
      token = ApiToken.generate!(name: "svc", created_by: admin)
      expect(token.created_by).to eq(admin)
    end

    it "requires a name" do
      expect { ApiToken.generate!(name: "") }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  describe ".authenticate" do
    it "returns the token for a valid plaintext" do
      token = ApiToken.generate!(name: "svc")
      expect(ApiToken.authenticate(token.raw_token)).to eq(token)
    end

    it "returns nil for blank, unknown, or revoked tokens" do
      token = ApiToken.generate!(name: "svc")
      raw = token.raw_token

      expect(ApiToken.authenticate(nil)).to be_nil
      expect(ApiToken.authenticate("")).to be_nil
      expect(ApiToken.authenticate("cnd_live_ffffffffffffffffffffffff")).to be_nil

      token.revoke!
      expect(ApiToken.authenticate(raw)).to be_nil
    end
  end

  describe "#touch_last_used!" do
    it "stamps last_used_at, but at most once per minute" do
      token = ApiToken.generate!(name: "svc")
      token.touch_last_used!
      first = token.reload.last_used_at
      expect(first).to be_present

      token.touch_last_used!
      expect(token.reload.last_used_at).to eq(first)

      token.update_column(:last_used_at, 2.minutes.ago)
      token.touch_last_used!
      expect(token.reload.last_used_at).to be > first - 3.minutes
      expect(token.reload.last_used_at).to be_within(5.seconds).of(Time.current)
    end
  end

  describe "#revoke! / .active" do
    it "excludes revoked tokens from the active scope" do
      token = ApiToken.generate!(name: "svc")
      expect(ApiToken.active).to include(token)
      token.revoke!
      expect(token).to be_revoked
      expect(ApiToken.active).not_to include(token)
    end
  end
end
```

- [ ] **Step 4: Run spec to verify it fails**

```bash
bundle exec rspec spec/models/api_token_spec.rb
```

Expected: FAIL — `uninitialized constant ApiToken`.

- [ ] **Step 5: Write the model**

Create `app/models/api_token.rb`:

```ruby
# Bearer tokens for the public read API (/api/v1). Plaintext is generated
# once and never stored — only its SHA-256 digest. Lookup is by unique digest
# index (the standard API-token pattern: a preimage-resistant digest makes
# timing attacks on the index lookup impractical).
class ApiToken < ApplicationRecord
  TOKEN_PREFIX = "cnd_live_".freeze

  belongs_to :created_by, class_name: "User", optional: true

  validates :name, presence: true
  validates :token_digest, presence: true, uniqueness: true

  scope :active, -> { where(revoked_at: nil) }

  # Plaintext token, present only on the instance returned by generate!.
  attr_reader :raw_token

  def self.generate!(name:, created_by: nil)
    raw = TOKEN_PREFIX + SecureRandom.hex(12)
    token = create!(name: name, created_by: created_by, token_digest: digest(raw))
    token.instance_variable_set(:@raw_token, raw)
    token
  end

  def self.digest(raw)
    Digest::SHA256.hexdigest(raw)
  end

  def self.authenticate(raw)
    return nil if raw.blank?

    active.find_by(token_digest: digest(raw))
  end

  def revoked?
    revoked_at.present?
  end

  def revoke!
    update!(revoked_at: Time.current)
  end

  # Throttled to one write per minute to avoid write amplification on
  # high-volume consumers. update_column: no validations, no updated_at bump,
  # no PaperTrail noise.
  def touch_last_used!
    return if last_used_at && last_used_at > 1.minute.ago

    update_column(:last_used_at, Time.current)
  end
end
```

- [ ] **Step 6: Run spec to verify it passes**

```bash
bundle exec rspec spec/models/api_token_spec.rb
```

Expected: PASS (all examples).

- [ ] **Step 7: Commit**

```bash
git add db/migrate db/schema.rb app/models/api_token.rb spec/models/api_token_spec.rb
git commit -m "Add ApiToken model for public API bearer auth"
```

---

### Task 2: Api::V1 base controller, serializers, routes, and `GET /api/v1/people/:person_uuid`

**Files:**
- Create: `app/controllers/api/v1/base_controller.rb`
- Create: `app/controllers/api/v1/serializers.rb`
- Create: `app/controllers/api/v1/people_controller.rb` (show only in this task; index added in Task 4)
- Modify: `config/routes.rb:24-45` (add `namespace :v1` inside `namespace :api`)
- Test: `spec/requests/api_v1/auth_spec.rb`, `spec/requests/api_v1/people_show_spec.rb`

**Interfaces:**
- Consumes: `ApiToken.authenticate(raw)`, `#touch_last_used!` (Task 1).
- Produces: `Api::V1::BaseController` with private helpers `json_response(data, meta:, status:)`, `paginate(relation) → [records, meta]` (per_page max 500), `updated_since_param → Time|nil` (renders 400 INVALID_PARAM and returns nil on bad input — callers must `return if performed?`), `@api_token` set after auth. `Api::V1::Serializers` module with: `person_core_json(person)`, `person_full_json(person)`, `party_ref(party)`, `primary_party_of(person)`, `verified_socials(person)`, `social_json(account)`, `office_json(office)`, `district_json(district)`, `contest_json(contest)` — exact shapes below; Tasks 4–6 and the docs rely on these.

- [ ] **Step 1: Write the failing auth request spec**

Create `spec/requests/api_v1/auth_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe "Api::V1 authentication", type: :request do
  let!(:person) { create(:person) } # any routable record for a probe request
  let(:api_token) { ApiToken.generate!(name: "spec-consumer") }
  let(:probe_path) { "/api/v1/people/#{person.reload.person_uuid || 'missing'}" }

  before { person.update!(person_uuid: SecureRandom.uuid) }

  it "returns 401 UNAUTHORIZED with no Authorization header" do
    get probe_path
    expect(response).to have_http_status(:unauthorized)
    expect(JSON.parse(response.body)["code"]).to eq("UNAUTHORIZED")
  end

  it "returns 401 for a malformed or unknown token" do
    get probe_path, headers: { "Authorization" => "Bearer nonsense" }
    expect(response).to have_http_status(:unauthorized)

    get probe_path, headers: { "Authorization" => "Token abc" }
    expect(response).to have_http_status(:unauthorized)
  end

  it "returns 401 for a revoked token" do
    raw = api_token.raw_token
    api_token.revoke!
    get probe_path, headers: { "Authorization" => "Bearer #{raw}" }
    expect(response).to have_http_status(:unauthorized)
  end

  it "authenticates a valid token and stamps last_used_at" do
    expect(api_token.last_used_at).to be_nil
    get probe_path, headers: { "Authorization" => "Bearer #{api_token.raw_token}" }
    expect(response).to have_http_status(:ok)
    expect(api_token.reload.last_used_at).to be_present
  end

  it "does not create a session or require CSRF" do
    get probe_path, headers: { "Authorization" => "Bearer #{api_token.raw_token}" }
    expect(response.headers["Set-Cookie"].to_s).not_to include("_session")
  end
end
```

- [ ] **Step 2: Write the failing people#show spec**

Create `spec/requests/api_v1/people_show_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe "GET /api/v1/people/:person_uuid", type: :request do
  let(:api_token) { ApiToken.generate!(name: "spec-consumer") }
  let(:headers) { { "Authorization" => "Bearer #{api_token.raw_token}" } }

  let!(:party) { Party.create!(name: "Democratic", abbreviation: "D") }
  let!(:person) do
    Person.create!(
      first_name: "Kathy", last_name: "Hochul", state_of_residence: "NY",
      person_uuid: SecureRandom.uuid, gender: "Female", race: "White",
      website_official: "https://governor.ny.gov",
      website_campaign: "https://kathyhochul.com",
      photo_url: "https://example.com/kh.jpg", wikipedia_id: "Kathy_Hochul"
    ).tap { |p| p.add_party(party, is_primary: true) }
  end

  let!(:verified_account) do
    person.social_media_accounts.create!(
      platform: "Twitter", handle: "GovKathyHochul",
      url: "https://twitter.com/GovKathyHochul",
      channel_type: "Official Office", verified: true, research_status: "verified"
    )
  end
  let!(:unverified_account) do
    person.social_media_accounts.create!(
      platform: "TikTok", handle: "kathyhochul",
      url: "https://www.tiktok.com/@kathyhochul",
      channel_type: "Campaign", verified: false, research_status: "entered"
    )
  end
  let!(:inactive_verified_account) do
    person.social_media_accounts.create!(
      platform: "Facebook", handle: "OldPage", url: "https://facebook.com/OldPage",
      channel_type: "Campaign", verified: true, account_inactive: true
    )
  end

  it "returns the person with verified active socials, party, demographics, websites" do
    get "/api/v1/people/#{person.person_uuid}", headers: headers

    expect(response).to have_http_status(:ok)
    data = JSON.parse(response.body)["data"]

    expect(data["person_uuid"]).to eq(person.person_uuid)
    expect(data["id"]).to eq(person.id)
    expect(data["full_name"]).to eq("Kathy Hochul")
    expect(data["gender"]).to eq("Female")
    expect(data["race"]).to eq("White")
    expect(data["websites"]).to eq(
      "official" => "https://governor.ny.gov",
      "campaign" => "https://kathyhochul.com",
      "personal" => nil
    )
    expect(data["party"]).to eq("name" => "Democratic", "abbreviation" => "D")
    expect(data["parties"]).to eq([{ "name" => "Democratic", "abbreviation" => "D", "is_primary" => true }])

    platforms = data["social_media_accounts"].map { |a| a["platform"] }
    expect(platforms).to eq(["Twitter"]) # verified + active only
    expect(data["social_media_accounts"].first).to eq(
      "platform" => "Twitter", "handle" => "GovKathyHochul",
      "url" => "https://twitter.com/GovKathyHochul", "channel_type" => "Official Office"
    )
  end

  it "never leaks workflow fields" do
    get "/api/v1/people/#{person.person_uuid}", headers: headers
    body = response.body
    %w[research_status entered_by verified_by junkipedia needs_secondary_verification].each do |field|
      expect(body).not_to include(field)
    end
  end

  it "includes current offices and candidacies" do
    office = Office.create!(title: "Governor", level: "state", branch: "executive",
                            state: "NY", office_category: "Governor")
    Officeholder.create!(person: person, office: office, start_date: Date.new(2021, 8, 24))
    election = Election.create!(state: "NY", date: Date.new(2026, 6, 23), election_type: "primary", year: 2026)
    ballot = Ballot.create!(state: "NY", date: election.date, election_type: "primary",
                            party: "Democratic", year: 2026, election: election)
    contest = Contest.create!(office: office, ballot: ballot, date: ballot.date,
                              party: "Democratic", contest_type: "primary")
    Candidate.create!(person: person, contest: contest, outcome: "won", incumbent: true,
                      party_at_time: "Democratic")

    get "/api/v1/people/#{person.person_uuid}", headers: headers
    data = JSON.parse(response.body)["data"]

    expect(data["current_offices"].length).to eq(1)
    expect(data["current_offices"].first["title"]).to eq("Governor")
    expect(data["candidacies"].length).to eq(1)
    expect(data["candidacies"].first).to include(
      "outcome" => "won", "winner" => true, "incumbent" => true, "party_at_time" => "Democratic"
    )
  end

  it "404s on an unknown uuid" do
    get "/api/v1/people/#{SecureRandom.uuid}", headers: headers
    expect(response).to have_http_status(:not_found)
    expect(JSON.parse(response.body)["code"]).to eq("NOT_FOUND")
  end
end
```

- [ ] **Step 3: Run both specs to verify they fail**

```bash
bundle exec rspec spec/requests/api_v1
```

Expected: FAIL — routing errors (no route matches `/api/v1/...`).

- [ ] **Step 4: Add routes**

In `config/routes.rb`, inside the existing `namespace :api do ... end` block (after the `resources :states` line, before the closing `end`), add:

```ruby
    # Public read-only API (Bearer-token auth via ApiToken; see docs/PUBLIC_API.md)
    namespace :v1 do
      resources :officeholders, only: [:index]
      resources :candidates, only: [:index]
      resources :people, only: [:index]
      get "people/:person_uuid", to: "people#show", as: :person
    end
```

(The `officeholders`/`candidates`/`people` index routes exist from here on but their actions arrive in Tasks 4–6 — hitting one early raises ActionNotFound. Nothing calls them until their task adds the action + spec, so this is safe.)

- [ ] **Step 5: Write the serializers module**

Create `app/controllers/api/v1/serializers.rb`:

```ruby
module Api
  module V1
    # Hand-rolled JSON shapes for the public API. This is the public contract:
    # change shapes here only additively (docs/PUBLIC_API.md documents them).
    # Workflow fields (research_status, verified_by, junkipedia_*, etc.) must
    # never appear here. Socials: verified + active only.
    module Serializers
      def person_core_json(person)
        {
          id: person.id,
          person_uuid: person.person_uuid,
          first_name: person.first_name,
          middle_name: person.middle_name,
          last_name: person.last_name,
          suffix: person.suffix,
          full_name: person.full_name,
          state_of_residence: person.state_of_residence,
          gender: person.gender,
          race: person.race,
          photo_url: person.photo_url,
          wikipedia_id: person.wikipedia_id,
          websites: {
            official: person.website_official,
            campaign: person.website_campaign,
            personal: person.website_personal
          },
          party: party_ref(primary_party_of(person)),
          parties: person.person_parties.map { |pp|
            party_ref(pp.party).merge(is_primary: pp.is_primary == true)
          },
          social_media_accounts: verified_socials(person).map { |a| social_json(a) },
          updated_at: person.updated_at&.iso8601
        }
      end

      def person_full_json(person)
        person_core_json(person).merge(
          current_offices: person.officeholders.select(&:current?).map { |oh|
            office_json(oh.office).merge(start_date: oh.start_date, elected_year: oh.elected_year)
          },
          candidacies: person.candidates.map { |c|
            {
              id: c.id,
              outcome: c.outcome,
              winner: c.winner?,
              incumbent: c.incumbent == true,
              party_at_time: c.party_at_time,
              tally: c.tally,
              contest: {
                id: c.contest.id,
                name: c.contest.full_name,
                contest_type: c.contest.contest_type,
                party: c.contest.party,
                date: c.contest.date
              }
            }
          }
        )
      end

      # Loaded-association-safe primary party (avoids N+1 in index actions),
      # with the legacy party_affiliation fallback Person#primary_party uses.
      def primary_party_of(person)
        person.person_parties.find { |pp| pp.is_primary }&.party || person.party_affiliation
      end

      def verified_socials(person)
        person.social_media_accounts.select { |a| a.verified && !a.account_inactive }
      end

      def social_json(account)
        {
          platform: account.platform,
          handle: account.handle,
          url: account.url,
          channel_type: account.channel_type
        }
      end

      def party_ref(party)
        return nil unless party

        { name: party.name, abbreviation: party.abbreviation }
      end

      def office_json(office)
        {
          id: office.id,
          title: office.title,
          level: office.level,
          branch: office.branch,
          role: office.role,
          office_category: office.office_category,
          body_name: office.body_name,
          state: office.state,
          seat: office.seat,
          county: office.county,
          jurisdiction: office.jurisdiction,
          ocdid: office.ocdid,
          district: district_json(office.district)
        }
      end

      def district_json(district)
        return nil unless district

        {
          state: district.state,
          district_number: district.district_number,
          chamber: district.chamber,
          level: district.level,
          ocdid: district.ocdid
        }
      end

      def contest_json(contest)
        ballot = contest.ballot
        {
          id: contest.id,
          name: contest.full_name,
          contest_type: contest.contest_type,
          party: contest.party,
          date: contest.date,
          office: office_json(contest.office),
          ballot: ballot && {
            id: ballot.id,
            state: ballot.state,
            date: ballot.date,
            election_type: ballot.election_type,
            party: ballot.party,
            year: ballot.year,
            election: ballot.election && {
              id: ballot.election.id,
              state: ballot.election.state,
              date: ballot.election.date,
              election_type: ballot.election.election_type,
              year: ballot.election.year
            }
          }
        }
      end
    end
  end
end
```

- [ ] **Step 6: Write the base controller**

Create `app/controllers/api/v1/base_controller.rb`:

```ruby
module Api
  module V1
    # Public read-only API. Header-only Bearer token auth (ApiToken); no
    # sessions, CSRF, or Devise involvement. Conventions match the internal
    # /api (envelope, error codes, pagination shape) but serializers are
    # independent — this contract must stay stable for external consumers.
    class BaseController < ActionController::API
      include Api::V1::Serializers

      DEFAULT_PER_PAGE = 25
      MAX_PER_PAGE = 500

      before_action :authenticate_api_token!

      rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

      private

      def authenticate_api_token!
        raw = request.headers["Authorization"].to_s[/\ABearer (.+)\z/, 1]
        @api_token = ApiToken.authenticate(raw)

        if @api_token
          @api_token.touch_last_used!
        else
          render json: { error: "Invalid or missing API token", code: "UNAUTHORIZED" },
                 status: :unauthorized
        end
      end

      def render_not_found(exception)
        render json: { error: exception.message, code: "NOT_FOUND" }, status: :not_found
      end

      def json_response(data, meta: nil, status: :ok)
        body = { data: data }
        body[:meta] = meta if meta.present?
        render json: body, status: status
      end

      def paginate(relation)
        page = params[:page].to_i.clamp(1, 1_000_000)
        per_page = (params[:per_page].presence || DEFAULT_PER_PAGE).to_i.clamp(1, MAX_PER_PAGE)

        total = relation.count
        total_pages = (total.to_f / per_page).ceil
        records = relation.limit(per_page).offset((page - 1) * per_page)

        meta = {
          total: total,
          page: page,
          per_page: per_page,
          total_pages: total_pages,
          has_next_page: page < total_pages,
          has_previous_page: page > 1
        }
        [records, meta]
      end

      # Parses ?updated_since= as ISO8601. On bad input renders 400 and returns
      # nil — callers must bail with `return if performed?` after calling.
      def updated_since_param
        return nil if params[:updated_since].blank?

        Time.iso8601(params[:updated_since])
      rescue ArgumentError
        render json: { error: "updated_since must be an ISO8601 timestamp", code: "INVALID_PARAM" },
               status: :bad_request
        nil
      end
    end
  end
end
```

- [ ] **Step 7: Write the people controller (show only)**

Create `app/controllers/api/v1/people_controller.rb`:

```ruby
module Api
  module V1
    class PeopleController < BaseController
      # GET /api/v1/people/:person_uuid
      def show
        person = Person.includes(
          :party_affiliation, :social_media_accounts,
          { person_parties: :party },
          { officeholders: { office: :district } },
          { candidates: { contest: [:office, :ballot] } }
        ).find_by!(person_uuid: params[:person_uuid])

        json_response(person_full_json(person))
      end
    end
  end
end
```

- [ ] **Step 8: Run the specs to verify they pass**

```bash
bundle exec rspec spec/requests/api_v1
```

Expected: PASS (all examples in auth_spec and people_show_spec).

- [ ] **Step 9: Run the full suite to catch regressions**

```bash
bundle exec rspec
```

Expected: PASS — no existing spec touches these new paths.

- [ ] **Step 10: Commit**

```bash
git add config/routes.rb app/controllers/api/v1 spec/requests/api_v1
git commit -m "Add public API v1 base: bearer auth, serializers, people show"
```

---

### Task 3: Touch associations for honest incremental sync

**Files:**
- Modify: `app/models/social_media_account.rb:4` (`belongs_to :person`)
- Modify: `app/models/person_party.rb:4` (`belongs_to :person`)
- Test: `spec/models/touch_person_spec.rb`

**Interfaces:**
- Produces: saving/destroying a `SocialMediaAccount` or `PersonParty` bumps its person's `updated_at`, so `/api/v1/people?updated_since=` catches social/party changes. (Note: `update_all` paths — e.g. `Person#mark_for_secondary_verification_if_needed!`, `primary_party=` — bypass touch by design; those mutate workflow fields not exposed publicly, or run alongside a person save.)

- [ ] **Step 1: Write the failing spec**

Create `spec/models/touch_person_spec.rb`:

```ruby
require 'rails_helper'

# The public API's incremental sync (?updated_since=) relies on association
# changes bumping people.updated_at. Pin that here.
RSpec.describe "Person touch on association change", type: :model do
  let(:person) { create(:person) }

  it "bumps person.updated_at when a social media account is created, updated, or destroyed" do
    person.update_column(:updated_at, 1.day.ago)
    account = person.social_media_accounts.create!(platform: "Twitter", handle: "abc",
                                                   url: "https://twitter.com/abc")
    expect(person.reload.updated_at).to be > 1.hour.ago

    person.update_column(:updated_at, 1.day.ago)
    account.update!(handle: "def", url: "https://twitter.com/def")
    expect(person.reload.updated_at).to be > 1.hour.ago

    person.update_column(:updated_at, 1.day.ago)
    account.destroy!
    expect(person.reload.updated_at).to be > 1.hour.ago
  end

  it "bumps person.updated_at when a party affiliation changes" do
    party = Party.create!(name: "Green", abbreviation: "G")
    person.update_column(:updated_at, 1.day.ago)
    person.add_party(party, is_primary: true)
    expect(person.reload.updated_at).to be > 1.hour.ago
  end
end
```

- [ ] **Step 2: Run spec to verify it fails**

```bash
bundle exec rspec spec/models/touch_person_spec.rb
```

Expected: FAIL — `updated_at` stays 1 day old.

- [ ] **Step 3: Add touch to both associations**

In `app/models/social_media_account.rb` change line 4:

```ruby
  belongs_to :person, touch: true
```

In `app/models/person_party.rb` change line 4:

```ruby
  belongs_to :person, touch: true
```

- [ ] **Step 4: Run spec + full suite to verify pass and no regressions**

```bash
bundle exec rspec spec/models/touch_person_spec.rb && bundle exec rspec
```

Expected: PASS. (Watch the verification-workflow specs in particular — `touch` does not fire save callbacks or create PaperTrail versions, so they should be unaffected. If any fail, stop and investigate before proceeding.)

- [ ] **Step 5: Commit**

```bash
git add app/models/social_media_account.rb app/models/person_party.rb spec/models/touch_person_spec.rb
git commit -m "Touch person on social account / party changes for API incremental sync"
```

---

### Task 4: `GET /api/v1/people` index

**Files:**
- Modify: `app/controllers/api/v1/people_controller.rb` (add `index`)
- Test: `spec/requests/api_v1/people_index_spec.rb`

**Interfaces:**
- Consumes: `paginate`, `updated_since_param`, `person_full_json` (Task 2).
- Produces: `GET /api/v1/people?state=&q=&updated_since=&page=&per_page=` → `{data: [person_full_json…], meta: pagination}` ordered by id.

- [ ] **Step 1: Write the failing spec**

Create `spec/requests/api_v1/people_index_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe "GET /api/v1/people", type: :request do
  let(:api_token) { ApiToken.generate!(name: "spec-consumer") }
  let(:headers) { { "Authorization" => "Bearer #{api_token.raw_token}" } }

  let!(:ny_person) do
    Person.create!(first_name: "Kathy", last_name: "Hochul",
                   state_of_residence: "NY", person_uuid: SecureRandom.uuid)
  end
  let!(:tx_person) do
    Person.create!(first_name: "Greg", last_name: "Abbott",
                   state_of_residence: "TX", person_uuid: SecureRandom.uuid)
  end

  def get_index(params = {})
    get "/api/v1/people", params: params, headers: headers
    JSON.parse(response.body)
  end

  it "returns paginated people ordered by id" do
    body = get_index
    expect(response).to have_http_status(:ok)
    expect(body["data"].map { |p| p["id"] }).to eq([ny_person.id, tx_person.id].sort)
    expect(body["meta"]).to include("total" => 2, "page" => 1, "per_page" => 25)
  end

  it "filters by state" do
    body = get_index(state: "TX")
    expect(body["data"].map { |p| p["last_name"] }).to eq(["Abbott"])
  end

  it "filters by name search q" do
    body = get_index(q: "hoch")
    expect(body["data"].map { |p| p["last_name"] }).to eq(["Hochul"])

    body = get_index(q: "kathy hochul")
    expect(body["data"].map { |p| p["last_name"] }).to eq(["Hochul"])
  end

  it "filters by updated_since" do
    ny_person.update_column(:updated_at, 3.days.ago)
    body = get_index(updated_since: 1.day.ago.iso8601)
    expect(body["data"].map { |p| p["id"] }).to eq([tx_person.id])
  end

  it "400s on malformed updated_since" do
    get "/api/v1/people", params: { updated_since: "not-a-date" }, headers: headers
    expect(response).to have_http_status(:bad_request)
    expect(JSON.parse(response.body)["code"]).to eq("INVALID_PARAM")
  end

  it "caps per_page at 500" do
    body = get_index(per_page: 9999)
    expect(body["meta"]["per_page"]).to eq(500)
  end
end
```

- [ ] **Step 2: Run spec to verify it fails**

```bash
bundle exec rspec spec/requests/api_v1/people_index_spec.rb
```

Expected: FAIL — `The action 'index' could not be found for Api::V1::PeopleController`.

- [ ] **Step 3: Add the index action**

In `app/controllers/api/v1/people_controller.rb`, add above `show`:

```ruby
      # GET /api/v1/people?state=&q=&updated_since=&page=&per_page=
      def index
        since = updated_since_param
        return if performed?

        scope = Person.order(:id)
        scope = scope.by_state(params[:state]) if params[:state].present?
        scope = scope.where("people.updated_at >= ?", since) if since

        if params[:q].present?
          params[:q].split(/\s+/).each do |term|
            pattern = "%#{Person.sanitize_sql_like(term)}%"
            scope = scope.where("first_name ILIKE :p OR last_name ILIKE :p OR middle_name ILIKE :p", p: pattern)
          end
        end

        records, meta = paginate(
          scope.includes(
            :party_affiliation, :social_media_accounts,
            { person_parties: :party },
            { officeholders: { office: :district } },
            { candidates: { contest: [:office, :ballot] } }
          )
        )
        json_response(records.map { |p| person_full_json(p) }, meta: meta)
      end
```

- [ ] **Step 4: Run spec to verify it passes**

```bash
bundle exec rspec spec/requests/api_v1/people_index_spec.rb
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/controllers/api/v1/people_controller.rb spec/requests/api_v1/people_index_spec.rb
git commit -m "Add public API people index with state/q/updated_since filters"
```

---

### Task 5: `GET /api/v1/officeholders`

**Files:**
- Create: `app/controllers/api/v1/officeholders_controller.rb`
- Test: `spec/requests/api_v1/officeholders_spec.rb`

**Interfaces:**
- Consumes: `paginate`, `updated_since_param`, `person_core_json`, `office_json` (Task 2).
- Produces: `GET /api/v1/officeholders?state=&level=&branch=&office_category=&body_name=&district=&chamber=&party=&current=&updated_since=` → rows shaped `{id, start_date, end_date, elected_year, appointed, current, updated_at, person: person_core_json, office: office_json}`. Defaults to current officeholders; `current=false` includes historical.

- [ ] **Step 1: Write the failing spec**

Create `spec/requests/api_v1/officeholders_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe "GET /api/v1/officeholders", type: :request do
  let(:api_token) { ApiToken.generate!(name: "spec-consumer") }
  let(:headers) { { "Authorization" => "Bearer #{api_token.raw_token}" } }

  let!(:dem) { Party.create!(name: "Democratic", abbreviation: "D") }
  let!(:rep) { Party.create!(name: "Republican", abbreviation: "R") }

  # Congressional districts in this schema: level "federal", chamber nil
  # (see District.congressional). State-house districts: level "state",
  # chamber "lower".
  let!(:tx14) do
    District.create!(state: "TX", district_number: 14, level: "federal")
  end
  let!(:tx_hd5) do
    District.create!(state: "TX", district_number: 5, level: "state", chamber: "lower")
  end
  let!(:house_office) do
    Office.create!(title: "U.S. Representative TX-14", level: "federal", branch: "legislative",
                   state: "TX", office_category: "U.S. Representative",
                   body_name: "U.S. House of Representatives", district: tx14)
  end
  let!(:senate_office) do
    Office.create!(title: "U.S. Senator (NY)", level: "federal", branch: "legislative",
                   state: "NY", office_category: "U.S. Senator", body_name: "U.S. Senate")
  end
  let!(:state_house_office) do
    Office.create!(title: "TX State Representative HD-5", level: "state", branch: "legislative",
                   state: "TX", office_category: "State Representative",
                   body_name: "TX State House", district: tx_hd5)
  end

  let!(:rep_person) do
    Person.create!(first_name: "Randy", last_name: "Weber", state_of_residence: "TX",
                   person_uuid: SecureRandom.uuid).tap { |p| p.add_party(rep, is_primary: true) }
  end
  let!(:sen_person) do
    Person.create!(first_name: "Kirsten", last_name: "Gillibrand", state_of_residence: "NY",
                   person_uuid: SecureRandom.uuid).tap { |p| p.add_party(dem, is_primary: true) }
  end

  let!(:current_rep) do
    Officeholder.create!(person: rep_person, office: house_office,
                         start_date: Date.new(2025, 1, 3), elected_year: 2024)
  end
  let!(:current_sen) do
    Officeholder.create!(person: sen_person, office: senate_office,
                         start_date: Date.new(2025, 1, 3))
  end
  let!(:former_holder) do
    Officeholder.create!(person: sen_person, office: house_office,
                         start_date: Date.new(2019, 1, 3), end_date: Date.new(2021, 1, 3))
  end
  let!(:state_rep_person) do
    Person.create!(first_name: "Terri", last_name: "Leo", state_of_residence: "TX",
                   person_uuid: SecureRandom.uuid).tap { |p| p.add_party(rep, is_primary: true) }
  end
  let!(:current_state_rep) do
    Officeholder.create!(person: state_rep_person, office: state_house_office,
                         start_date: Date.new(2025, 1, 14), elected_year: 2024)
  end

  def get_index(params = {})
    get "/api/v1/officeholders", params: params, headers: headers
    JSON.parse(response.body)
  end

  it "returns only current officeholders by default, with person and office embedded" do
    body = get_index
    expect(response).to have_http_status(:ok)
    ids = body["data"].map { |o| o["id"] }
    expect(ids).to contain_exactly(current_rep.id, current_sen.id, current_state_rep.id)

    row = body["data"].find { |o| o["id"] == current_rep.id }
    expect(row["current"]).to be(true)
    expect(row["person"]["full_name"]).to eq("Randy Weber")
    expect(row["person"]["party"]).to eq("name" => "Republican", "abbreviation" => "R")
    expect(row["office"]["office_category"]).to eq("U.S. Representative")
    expect(row["office"]["district"]).to include("state" => "TX", "district_number" => 14, "chamber" => nil)
  end

  it "includes former officeholders with current=false" do
    body = get_index(current: "false")
    expect(body["data"].map { |o| o["id"] }).to include(former_holder.id)
  end

  it "answers 'who is the TX-14 rep'" do
    body = get_index(state: "TX", office_category: "U.S. Representative", district: 14)
    expect(body["data"].length).to eq(1)
    expect(body["data"].first["person"]["last_name"]).to eq("Weber")
  end

  it "filters by state, level, branch, body_name, chamber" do
    expect(get_index(state: "NY")["data"].map { |o| o["id"] }).to eq([current_sen.id])
    expect(get_index(level: "federal")["data"].length).to eq(2)
    expect(get_index(branch: "executive")["data"]).to be_empty
    expect(get_index(body_name: "U.S. Senate")["data"].map { |o| o["id"] }).to eq([current_sen.id])
    # chamber filters via the district — congressional districts have nil
    # chamber, so only the state-house holder matches "lower"
    expect(get_index(chamber: "lower")["data"].map { |o| o["id"] }).to eq([current_state_rep.id])
  end

  it "filters by party (name or abbreviation, primary party)" do
    expect(get_index(party: "Republican")["data"].map { |o| o["id"] })
      .to contain_exactly(current_rep.id, current_state_rep.id)
    expect(get_index(party: "D")["data"].map { |o| o["id"] }).to eq([current_sen.id])
  end

  it "filters by party via the legacy party_affiliation fallback" do
    legacy = Person.create!(first_name: "Leg", last_name: "Acy", state_of_residence: "TX",
                            person_uuid: SecureRandom.uuid, party_affiliation: rep)
    holder = Officeholder.create!(person: legacy, office: senate_office, start_date: Date.new(2025, 1, 3))
    expect(get_index(party: "R")["data"].map { |o| o["id"] })
      .to contain_exactly(current_rep.id, current_state_rep.id, holder.id)
  end

  it "supports updated_since" do
    current_rep.update_column(:updated_at, 3.days.ago)
    current_state_rep.update_column(:updated_at, 3.days.ago)
    body = get_index(updated_since: 1.day.ago.iso8601)
    expect(body["data"].map { |o| o["id"] }).to eq([current_sen.id])
  end
end
```

- [ ] **Step 2: Run spec to verify it fails**

```bash
bundle exec rspec spec/requests/api_v1/officeholders_spec.rb
```

Expected: FAIL — `uninitialized constant Api::V1::OfficeholdersController`.

- [ ] **Step 3: Write the controller**

Create `app/controllers/api/v1/officeholders_controller.rb`:

```ruby
module Api
  module V1
    class OfficeholdersController < BaseController
      # GET /api/v1/officeholders — current by default (current=false for all).
      # Joins are all belongs_to (no row multiplication), except the party
      # filter which uses a subquery to avoid duplicates.
      def index
        since = updated_since_param
        return if performed?

        scope = Officeholder.joins(:office).order(:id)
        scope = scope.merge(Officeholder.current) unless params[:current] == "false"
        scope = scope.where("officeholders.updated_at >= ?", since) if since

        %i[state level branch office_category body_name].each do |field|
          scope = scope.where(offices: { field => params[field] }) if params[field].present?
        end

        if params[:district].present?
          scope = scope.joins(office: :district)
                       .where(districts: { district_number: params[:district] })
        end
        if params[:chamber].present?
          scope = scope.joins(office: :district).where(districts: { chamber: params[:chamber] })
        end

        if params[:party].present?
          party_ids = Party.where("name = :p OR abbreviation = :p", p: params[:party]).select(:id)
          scope = scope.joins(:person).where(
            "people.id IN (SELECT person_id FROM person_parties WHERE is_primary AND party_id IN (:ids)) " \
            "OR people.party_affiliation_id IN (:ids)",
            ids: party_ids
          )
        end

        records, meta = paginate(
          scope.includes(
            { person: [:party_affiliation, :social_media_accounts, { person_parties: :party }] },
            { office: :district }
          )
        )
        json_response(records.map { |oh| officeholder_json(oh) }, meta: meta)
      end

      private

      def officeholder_json(officeholder)
        {
          id: officeholder.id,
          start_date: officeholder.start_date,
          end_date: officeholder.end_date,
          elected_year: officeholder.elected_year,
          appointed: officeholder.appointed == true,
          current: officeholder.current?,
          updated_at: officeholder.updated_at&.iso8601,
          person: person_core_json(officeholder.person),
          office: office_json(officeholder.office)
        }
      end
    end
  end
end
```

- [ ] **Step 4: Run spec to verify it passes**

```bash
bundle exec rspec spec/requests/api_v1/officeholders_spec.rb
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/controllers/api/v1/officeholders_controller.rb spec/requests/api_v1/officeholders_spec.rb
git commit -m "Add public API officeholders endpoint (current-by-default, full filters)"
```

---

### Task 6: `GET /api/v1/candidates`

**Files:**
- Create: `app/controllers/api/v1/candidates_controller.rb`
- Test: `spec/requests/api_v1/candidates_spec.rb`

**Interfaces:**
- Consumes: `paginate`, `updated_since_param`, `person_core_json`, `contest_json` (Task 2); `Candidate::WINNING_OUTCOMES`, `Candidate.for_year`, `.incumbents`, `.challengers`.
- Produces: `GET /api/v1/candidates?year=&state=&office_category=&district=&chamber=&party=&outcome=&winners=&incumbent=&updated_since=` → rows shaped `{id, outcome, winner, incumbent, party_at_time, tally, updated_at, person: person_core_json, contest: contest_json}`.

- [ ] **Step 1: Write the failing spec**

Create `spec/requests/api_v1/candidates_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe "GET /api/v1/candidates", type: :request do
  let(:api_token) { ApiToken.generate!(name: "spec-consumer") }
  let(:headers) { { "Authorization" => "Bearer #{api_token.raw_token}" } }

  # A state-house race: gives us a district with a chamber so the
  # district/chamber/office_category filters can all be exercised on one office.
  let!(:ga_hd14) { District.create!(state: "GA", district_number: 14, level: "state", chamber: "lower") }
  let!(:office) do
    Office.create!(title: "GA State Representative HD-14", level: "state", branch: "legislative",
                   state: "GA", office_category: "State Representative",
                   body_name: "GA State House", district: ga_hd14)
  end
  let!(:election) { Election.create!(state: "GA", date: Date.new(2026, 5, 19), election_type: "primary", year: 2026) }
  let!(:ballot) do
    Ballot.create!(state: "GA", date: election.date, election_type: "primary",
                   party: "Republican", year: 2026, election: election)
  end
  let!(:contest) do
    Contest.create!(office: office, ballot: ballot, date: ballot.date,
                    party: "Republican", contest_type: "primary")
  end

  let!(:winner_person) do
    Person.create!(first_name: "Win", last_name: "Ner", state_of_residence: "GA", person_uuid: SecureRandom.uuid)
  end
  let!(:loser_person) do
    Person.create!(first_name: "Lo", last_name: "Ser", state_of_residence: "GA", person_uuid: SecureRandom.uuid)
  end
  let!(:advanced_person) do
    Person.create!(first_name: "Ad", last_name: "Vanced", state_of_residence: "GA", person_uuid: SecureRandom.uuid)
  end

  let!(:winner) do
    Candidate.create!(person: winner_person, contest: contest, outcome: "won",
                      incumbent: true, party_at_time: "Republican", tally: 100)
  end
  let!(:loser) do
    Candidate.create!(person: loser_person, contest: contest, outcome: "lost",
                      incumbent: false, party_at_time: "Republican", tally: 40)
  end
  let!(:advanced) do
    other_contest = Contest.create!(office: office, ballot: ballot, date: ballot.date,
                                    party: "Democratic", contest_type: "primary")
    Candidate.create!(person: advanced_person, contest: other_contest, outcome: "advanced",
                      incumbent: false, party_at_time: "Democratic")
  end

  def get_index(params = {})
    get "/api/v1/candidates", params: params, headers: headers
    JSON.parse(response.body)
  end

  it "returns candidates with person and contest chain embedded" do
    body = get_index
    expect(response).to have_http_status(:ok)
    expect(body["data"].length).to eq(3)

    row = body["data"].find { |c| c["id"] == winner.id }
    expect(row).to include("outcome" => "won", "winner" => true, "incumbent" => true,
                           "party_at_time" => "Republican", "tally" => 100)
    expect(row["person"]["full_name"]).to eq("Win Ner")
    expect(row["contest"]["contest_type"]).to eq("primary")
    expect(row["contest"]["office"]["district"]["district_number"]).to eq(14)
    expect(row["contest"]["ballot"]["election"]["year"]).to eq(2026)
  end

  it "filters by year, state, office_category, district, chamber" do
    expect(get_index(year: 2026)["data"].length).to eq(3)
    expect(get_index(year: 2024)["data"]).to be_empty
    expect(get_index(state: "GA")["data"].length).to eq(3)
    expect(get_index(state: "TX")["data"]).to be_empty
    expect(get_index(office_category: "State Representative")["data"].length).to eq(3)
    expect(get_index(district: 14)["data"].length).to eq(3)
    expect(get_index(district: 6)["data"]).to be_empty
    expect(get_index(chamber: "lower")["data"].length).to eq(3)
    expect(get_index(chamber: "upper")["data"]).to be_empty
  end

  it "filters by party_at_time" do
    expect(get_index(party: "Republican")["data"].map { |c| c["id"] }).to contain_exactly(winner.id, loser.id)
    expect(get_index(party: "Democratic")["data"].map { |c| c["id"] }).to eq([advanced.id])
  end

  it "filters by outcome, and winners=true includes won AND advanced" do
    expect(get_index(outcome: "lost")["data"].map { |c| c["id"] }).to eq([loser.id])
    expect(get_index(winners: "true")["data"].map { |c| c["id"] }).to contain_exactly(winner.id, advanced.id)
  end

  it "filters incumbents vs challengers" do
    expect(get_index(incumbent: "true")["data"].map { |c| c["id"] }).to eq([winner.id])
    expect(get_index(incumbent: "false")["data"].map { |c| c["id"] }).to contain_exactly(loser.id, advanced.id)
  end

  it "supports updated_since" do
    winner.update_column(:updated_at, 3.days.ago)
    loser.update_column(:updated_at, 3.days.ago)
    body = get_index(updated_since: 1.day.ago.iso8601)
    expect(body["data"].map { |c| c["id"] }).to eq([advanced.id])
  end
end
```

- [ ] **Step 2: Run spec to verify it fails**

```bash
bundle exec rspec spec/requests/api_v1/candidates_spec.rb
```

Expected: FAIL — `uninitialized constant Api::V1::CandidatesController`.

- [ ] **Step 3: Write the controller**

Create `app/controllers/api/v1/candidates_controller.rb`:

```ruby
module Api
  module V1
    class CandidatesController < BaseController
      # GET /api/v1/candidates — all joins are belongs_to chains (candidate →
      # contest → ballot/office → district), so no row multiplication.
      def index
        since = updated_since_param
        return if performed?

        scope = Candidate.joins(contest: [:ballot, :office]).order(:id)
        scope = scope.where("candidates.updated_at >= ?", since) if since
        scope = scope.merge(Candidate.for_year(params[:year].to_i)) if params[:year].present?
        scope = scope.where(ballots: { state: params[:state] }) if params[:state].present?
        scope = scope.where(offices: { office_category: params[:office_category] }) if params[:office_category].present?

        if params[:district].present?
          scope = scope.joins(contest: { office: :district })
                       .where(districts: { district_number: params[:district] })
        end
        if params[:chamber].present?
          scope = scope.joins(contest: { office: :district })
                       .where(districts: { chamber: params[:chamber] })
        end

        scope = scope.where(party_at_time: params[:party]) if params[:party].present?
        scope = scope.where(outcome: params[:outcome]) if params[:outcome].present?
        scope = scope.where(outcome: Candidate::WINNING_OUTCOMES) if params[:winners] == "true"

        case params[:incumbent]
        when "true" then scope = scope.merge(Candidate.incumbents)
        when "false" then scope = scope.merge(Candidate.challengers)
        end

        records, meta = paginate(
          scope.includes(
            { person: [:party_affiliation, :social_media_accounts, { person_parties: :party }] },
            { contest: [{ office: :district }, { ballot: :election }] }
          )
        )
        json_response(records.map { |c| candidate_json(c) }, meta: meta)
      end

      private

      def candidate_json(candidate)
        {
          id: candidate.id,
          outcome: candidate.outcome,
          winner: candidate.winner?,
          incumbent: candidate.incumbent == true,
          party_at_time: candidate.party_at_time,
          tally: candidate.tally,
          updated_at: candidate.updated_at&.iso8601,
          person: person_core_json(candidate.person),
          contest: contest_json(candidate.contest)
        }
      end
    end
  end
end
```

- [ ] **Step 4: Run spec to verify it passes**

```bash
bundle exec rspec spec/requests/api_v1/candidates_spec.rb
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/controllers/api/v1/candidates_controller.rb spec/requests/api_v1/candidates_spec.rb
git commit -m "Add public API candidates endpoint with winners/incumbent filters"
```

---

### Task 7: Rate limiting

**Files:**
- Modify: `app/controllers/api/v1/base_controller.rb` (add constant + before_action)
- Test: `spec/requests/api_v1/rate_limit_spec.rb`

**Interfaces:**
- Produces: authenticated requests beyond 300/minute per token get 429 `RATE_LIMITED`.
- **Deviation from spec doc:** the spec named Rails' built-in `rate_limit` macro; we use an equivalent hand-rolled before_action because the macro captures its cache store at class-load time, which makes it untestable under the test env's `:null_store` and unavailable on `ActionController::API` without extra caching modules. Behavior is identical (fixed window, per-token, 429).

- [ ] **Step 1: Write the failing spec**

Create `spec/requests/api_v1/rate_limit_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe "Api::V1 rate limiting", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:api_token) { ApiToken.generate!(name: "spec-consumer") }
  let(:headers) { { "Authorization" => "Bearer #{api_token.raw_token}" } }

  it "returns 429 RATE_LIMITED beyond 300 requests per minute per token" do
    memory_cache = ActiveSupport::Cache::MemoryStore.new
    allow(Rails).to receive(:cache).and_return(memory_cache)

    travel_to Time.current.beginning_of_minute + 5.seconds do
      key = "api_v1_rate:#{api_token.id}:#{Time.current.to_i / 60}"
      300.times { memory_cache.increment(key, 1, expires_in: 2.minutes) }

      get "/api/v1/people", headers: headers
      expect(response).to have_http_status(:too_many_requests)
      expect(JSON.parse(response.body)["code"]).to eq("RATE_LIMITED")
    end
  end

  it "does not limit under the threshold" do
    memory_cache = ActiveSupport::Cache::MemoryStore.new
    allow(Rails).to receive(:cache).and_return(memory_cache)

    get "/api/v1/people", headers: headers
    expect(response).to have_http_status(:ok)
  end

  it "no-ops when the cache store does not support increment counts (test default null_store)" do
    get "/api/v1/people", headers: headers
    expect(response).to have_http_status(:ok)
  end
end
```

- [ ] **Step 2: Run spec to verify it fails**

```bash
bundle exec rspec spec/requests/api_v1/rate_limit_spec.rb
```

Expected: the 429 example FAILS (gets 200); the others pass.

- [ ] **Step 3: Add the limiter to the base controller**

In `app/controllers/api/v1/base_controller.rb`:

Add below `MAX_PER_PAGE = 500`:

```ruby
      RATE_LIMIT_PER_MINUTE = 300
```

Add directly below `before_action :authenticate_api_token!` (order matters — auth first so `@api_token` is set):

```ruby
      before_action :enforce_rate_limit!
```

Add this private method below `authenticate_api_token!`:

```ruby
      # Fixed-window per-token throttle. Rails.cache increment returns nil on
      # stores without counters (test null_store) — then the limit is a no-op.
      def enforce_rate_limit!
        window = Time.current.to_i / 60
        count = Rails.cache.increment("api_v1_rate:#{@api_token.id}:#{window}", 1, expires_in: 2.minutes)
        return if count.nil? || count <= RATE_LIMIT_PER_MINUTE

        render json: { error: "Rate limit exceeded (#{RATE_LIMIT_PER_MINUTE}/minute)", code: "RATE_LIMITED" },
               status: :too_many_requests
      end
```

- [ ] **Step 4: Run spec + the other v1 specs to verify pass**

```bash
bundle exec rspec spec/requests/api_v1
```

Expected: PASS — other v1 specs unaffected (null_store → limiter no-ops).

- [ ] **Step 5: Commit**

```bash
git add app/controllers/api/v1/base_controller.rb spec/requests/api_v1/rate_limit_spec.rb
git commit -m "Add per-token rate limiting to public API"
```

---

### Task 8: Admin token management UI

**Files:**
- Modify: `config/routes.rb` (admin namespace)
- Create: `app/controllers/admin/api_tokens_controller.rb`
- Create: `app/views/admin/api_tokens/index.html.erb`, `new.html.erb`, `created.html.erb`
- Test: `spec/requests/admin_api_tokens_spec.rb`

**Interfaces:**
- Consumes: `ApiToken.generate!`, `#revoke!`, `.active` (Task 1); `Admin::BaseController` (existing — authenticates + requires admin, `layout 'admin'`).
- Produces: `/admin/api_tokens` (index), `/admin/api_tokens/new`, `POST /admin/api_tokens` (renders `created` view showing plaintext once), `POST /admin/api_tokens/:id/revoke`.

- [ ] **Step 1: Write the failing request spec**

Create `spec/requests/admin_api_tokens_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe "Admin API tokens", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:researcher) { create(:user) }

  it "blocks non-admins" do
    sign_in researcher
    get admin_api_tokens_path
    expect(response).to redirect_to(root_path)
  end

  context "as admin" do
    before { sign_in admin }

    it "lists tokens" do
      token = ApiToken.generate!(name: "listed-service")
      get admin_api_tokens_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("listed-service")
      expect(response.body).not_to include(token.raw_token)
    end

    it "creates a token and shows the plaintext exactly once" do
      post admin_api_tokens_path, params: { api_token: { name: "new-service" } }
      expect(response).to have_http_status(:ok)

      token = ApiToken.order(:id).last
      expect(token.name).to eq("new-service")
      expect(response.body).to include("cnd_live_") # plaintext displayed on the created page

      get admin_api_tokens_path # never displayed again
      expect(response.body).not_to match(/cnd_live_\h{24}/)
    end

    it "rejects a blank name" do
      expect {
        post admin_api_tokens_path, params: { api_token: { name: "" } }
      }.not_to change(ApiToken, :count)
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "revokes a token" do
      token = ApiToken.generate!(name: "doomed")
      post revoke_admin_api_token_path(token)
      expect(token.reload).to be_revoked
      expect(response).to redirect_to(admin_api_tokens_path)
    end
  end
end
```

- [ ] **Step 2: Run spec to verify it fails**

```bash
bundle exec rspec spec/requests/admin_api_tokens_spec.rb
```

Expected: FAIL — undefined `admin_api_tokens_path`.

- [ ] **Step 3: Add routes**

In `config/routes.rb`, inside `namespace :admin do`, after `resources :users do ... end` block, add:

```ruby
    resources :api_tokens, only: [:index, :new, :create] do
      member do
        post :revoke
      end
    end
```

- [ ] **Step 4: Write the controller**

Create `app/controllers/admin/api_tokens_controller.rb`:

```ruby
module Admin
  class ApiTokensController < Admin::BaseController
    # Manages bearer tokens for the public read API (/api/v1).
    # The plaintext token is shown exactly once, on the `created` page.
    def index
      @api_tokens = ApiToken.order(created_at: :desc)
    end

    def new
      @api_token = ApiToken.new
    end

    def create
      @api_token = ApiToken.generate!(
        name: params.require(:api_token)[:name],
        created_by: current_user
      )
      render :created
    rescue ActiveRecord::RecordInvalid => e
      @api_token = e.record
      render :new, status: :unprocessable_entity
    end

    def revoke
      token = ApiToken.find(params[:id])
      token.revoke!
      redirect_to admin_api_tokens_path, notice: "Token “#{token.name}” revoked."
    end
  end
end
```

- [ ] **Step 5: Write the views**

Create `app/views/admin/api_tokens/index.html.erb`:

```erb
<div class="max-w-5xl mx-auto py-6 px-4">
  <div class="flex items-center justify-between mb-6">
    <h1 class="text-2xl font-bold text-gray-900">API Tokens</h1>
    <%= link_to "New token", new_admin_api_token_path,
        class: "bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-md text-sm font-medium" %>
  </div>

  <p class="text-sm text-gray-600 mb-4">
    Bearer tokens for the public read API (<code>/api/v1</code>).
    See <code>docs/PUBLIC_API.md</code> for consumer documentation.
  </p>

  <div class="bg-white shadow rounded-lg overflow-hidden">
    <table class="min-w-full divide-y divide-gray-200">
      <thead class="bg-gray-50">
        <tr>
          <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Name</th>
          <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Created</th>
          <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Created by</th>
          <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Last used</th>
          <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Status</th>
          <th class="px-4 py-3"></th>
        </tr>
      </thead>
      <tbody class="divide-y divide-gray-200">
        <% @api_tokens.each do |token| %>
          <tr>
            <td class="px-4 py-3 text-sm font-medium text-gray-900"><%= token.name %></td>
            <td class="px-4 py-3 text-sm text-gray-500"><%= token.created_at.strftime("%Y-%m-%d") %></td>
            <td class="px-4 py-3 text-sm text-gray-500"><%= token.created_by&.name || "—" %></td>
            <td class="px-4 py-3 text-sm text-gray-500">
              <%= token.last_used_at ? "#{time_ago_in_words(token.last_used_at)} ago" : "never" %>
            </td>
            <td class="px-4 py-3 text-sm">
              <% if token.revoked? %>
                <span class="inline-flex px-2 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800">revoked</span>
              <% else %>
                <span class="inline-flex px-2 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">active</span>
              <% end %>
            </td>
            <td class="px-4 py-3 text-right text-sm">
              <% unless token.revoked? %>
                <%= button_to "Revoke", revoke_admin_api_token_path(token), method: :post,
                    data: { turbo_confirm: "Revoke “#{token.name}”? Consumers using it will get 401s immediately." },
                    class: "text-red-600 hover:text-red-800 font-medium" %>
              <% end %>
            </td>
          </tr>
        <% end %>
        <% if @api_tokens.empty? %>
          <tr><td colspan="6" class="px-4 py-8 text-center text-sm text-gray-500">No tokens yet.</td></tr>
        <% end %>
      </tbody>
    </table>
  </div>
</div>
```

Create `app/views/admin/api_tokens/new.html.erb`:

```erb
<div class="max-w-lg mx-auto py-6 px-4">
  <h1 class="text-2xl font-bold text-gray-900 mb-6">New API Token</h1>

  <%= form_with model: @api_token, url: admin_api_tokens_path, local: true do |f| %>
    <% if @api_token.errors.any? %>
      <div class="mb-4 p-3 bg-red-50 border border-red-200 rounded-md text-sm text-red-700">
        <%= @api_token.errors.full_messages.to_sentence %>
      </div>
    <% end %>

    <div class="mb-4">
      <%= f.label :name, "Consumer name", class: "block text-sm font-medium text-gray-700 mb-1" %>
      <%= f.text_field :name, placeholder: "e.g. junkipedia-sync, dashboard-service",
          class: "w-full border-gray-300 rounded-md shadow-sm" %>
      <p class="mt-1 text-xs text-gray-500">Name the service that will use this token — one token per consumer.</p>
    </div>

    <%= f.submit "Create token", class: "bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-md text-sm font-medium" %>
    <%= link_to "Cancel", admin_api_tokens_path, class: "ml-2 text-sm text-gray-600 hover:text-gray-900" %>
  <% end %>
</div>
```

Create `app/views/admin/api_tokens/created.html.erb`:

```erb
<div class="max-w-lg mx-auto py-6 px-4">
  <h1 class="text-2xl font-bold text-gray-900 mb-2">Token created</h1>
  <p class="text-sm text-gray-600 mb-6">
    Copy it now — <strong>it will not be shown again.</strong>
  </p>

  <div class="bg-amber-50 border border-amber-300 rounded-md p-4 mb-6">
    <div class="text-xs font-medium text-amber-800 uppercase mb-1"><%= @api_token.name %></div>
    <code class="block text-sm font-mono break-all select-all"><%= @api_token.raw_token %></code>
  </div>

  <p class="text-sm text-gray-600 mb-6">
    Consumers authenticate with:
    <code class="text-xs bg-gray-100 px-1 py-0.5 rounded">Authorization: Bearer <%= @api_token.raw_token.first(12) %>…</code>
  </p>

  <%= link_to "Back to tokens", admin_api_tokens_path,
      class: "bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-md text-sm font-medium" %>
</div>
```

- [ ] **Step 6: Run spec to verify it passes**

```bash
bundle exec rspec spec/requests/admin_api_tokens_spec.rb
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add config/routes.rb app/controllers/admin/api_tokens_controller.rb app/views/admin/api_tokens spec/requests/admin_api_tokens_spec.rb
git commit -m "Add admin UI for public API token management"
```

---

### Task 9: Integration verify script

**Files:**
- Create: `lib/scripts/public_api_verify.rb`

**Interfaces:**
- Consumes: all `/api/v1` endpoints (Tasks 2–7); dev DB with production data.
- Produces: `bin/rails runner lib/scripts/public_api_verify.rb` — creates a temp token, exercises every endpoint + auth failure + filters against real data, prints ok/FAIL per check, exits non-zero on failure, deletes the token.

- [ ] **Step 1: Write the script**

Create `lib/scripts/public_api_verify.rb`:

```ruby
# Integration verification for the public /api/v1 API.
# Run: bin/rails runner lib/scripts/public_api_verify.rb
# Read-only against the dev DB except for one temp ApiToken (deleted at the end).

$failures = []
$checks = 0

def check(label, condition, detail = nil)
  $checks += 1
  if condition
    puts "  ok  #{label}"
  else
    $failures << label
    puts "  FAIL #{label}#{detail ? " — #{detail}" : ''}"
  end
end

SESSION = ActionDispatch::Integration::Session.new(Rails.application)
SESSION.host! "localhost"

def api_get(path, token: nil, params: {})
  headers = token ? { "Authorization" => "Bearer #{token}" } : {}
  SESSION.get(path, params: params, headers: headers)
  body = begin
    JSON.parse(SESSION.response.body)
  rescue JSON::ParserError
    {}
  end
  [SESSION.response.status, body]
end

token = ApiToken.generate!(name: "public-api-verify-temp")
raw = token.raw_token

begin
  puts "== auth"
  status, body = api_get("/api/v1/people", params: { per_page: 1 })
  check("no token -> 401 UNAUTHORIZED", status == 401 && body["code"] == "UNAUTHORIZED")
  status, = api_get("/api/v1/people", token: "cnd_live_" + "0" * 24, params: { per_page: 1 })
  check("bad token -> 401", status == 401)
  status, body = api_get("/api/v1/people", token: raw, params: { per_page: 1 })
  check("valid token -> 200 with data+meta", status == 200 && body.key?("data") && body.key?("meta"))
  check("last_used_at stamped", token.reload.last_used_at.present?)

  puts "== officeholders"
  status, body = api_get("/api/v1/officeholders", token: raw, params: { per_page: 2 })
  check("index 200", status == 200)
  check("rows have person+office", body["data"].all? { |r| r["person"] && r["office"] })
  check("default rows are current", body["data"].all? { |r| r["current"] == true })

  sample = Officeholder.current.joins(office: :district)
                       .where.not(districts: { district_number: nil })
                       .where(offices: { office_category: "U.S. Representative" }).first
  if sample
    d = sample.office.district
    status, body = api_get("/api/v1/officeholders", token: raw,
                           params: { state: d.state, office_category: "U.S. Representative",
                                     district: d.district_number, chamber: d.chamber })
    found = body["data"].any? { |r| r["id"] == sample.id }
    check("district lookup finds known rep (#{d.state}-#{d.district_number})", status == 200 && found)
  else
    puts "  skip district lookup (no current U.S. Representative with district in DB)"
  end

  status, body = api_get("/api/v1/officeholders", token: raw, params: { party: "D", per_page: 5 })
  check("party filter returns rows", status == 200 && body["data"].any?)

  puts "== candidates"
  status, body = api_get("/api/v1/candidates", token: raw, params: { per_page: 2 })
  check("index 200 with contest chain", status == 200 &&
        body["data"].all? { |r| r["person"] && r["contest"] && r["contest"]["office"] })
  status, body = api_get("/api/v1/candidates", token: raw, params: { winners: "true", per_page: 100 })
  check("winners=true only won/advanced", status == 200 &&
        body["data"].all? { |r| %w[won advanced].include?(r["outcome"]) })
  status, body = api_get("/api/v1/candidates", token: raw, params: { incumbent: "true", per_page: 50 })
  check("incumbent=true only incumbents", status == 200 && body["data"].all? { |r| r["incumbent"] })

  puts "== people"
  status, body = api_get("/api/v1/people", token: raw, params: { per_page: 2 })
  check("index 200", status == 200)
  no_leak = !body.to_json.match?(/research_status|junkipedia|entered_by|needs_secondary/)
  check("no workflow fields in payload", no_leak)
  all_verified = body["data"].flat_map { |p| p["social_media_accounts"] }.none? { |a| a.key?("verified") }
  check("socials have no verified flag (implicitly verified-only)", all_verified)

  uuid_person = Person.where.not(person_uuid: nil).joins(:social_media_accounts)
                      .where(social_media_accounts: { verified: true }).first
  if uuid_person
    status, body = api_get("/api/v1/people/#{uuid_person.person_uuid}", token: raw)
    check("show by uuid 200", status == 200 && body["data"]["person_uuid"] == uuid_person.person_uuid)
    verified_count = uuid_person.social_media_accounts.verified.active.count
    check("show returns only verified+active socials (#{verified_count})",
          body["data"]["social_media_accounts"].length == verified_count)
  else
    puts "  skip uuid show (no person with uuid + verified account)"
  end
  status, body = api_get("/api/v1/people/00000000-0000-0000-0000-000000000000", token: raw)
  check("unknown uuid -> 404 NOT_FOUND", status == 404 && body["code"] == "NOT_FOUND")

  puts "== params"
  status, body = api_get("/api/v1/people", token: raw, params: { updated_since: "garbage" })
  check("bad updated_since -> 400 INVALID_PARAM", status == 400 && body["code"] == "INVALID_PARAM")
  status, body = api_get("/api/v1/people", token: raw, params: { per_page: 9999, page: 1 })
  check("per_page capped at 500", status == 200 && body["meta"]["per_page"] == 500)
  status, body = api_get("/api/v1/people", token: raw,
                         params: { updated_since: 1.week.ago.iso8601, per_page: 1 })
  check("updated_since filters", status == 200 && body["meta"]["total"] <= Person.count)

  puts "== revocation"
  token.revoke!
  status, = api_get("/api/v1/people", token: raw, params: { per_page: 1 })
  check("revoked token -> 401", status == 401)
ensure
  token.destroy
end

puts
if $failures.empty?
  puts "ALL #{$checks} CHECKS PASSED"
else
  puts "#{$failures.size}/#{$checks} FAILED: #{$failures.join(', ')}"
  exit 1
end
```

- [ ] **Step 2: Run it against the dev DB (fresh production pull)**

```bash
bin/rails runner lib/scripts/public_api_verify.rb
```

Expected: `ALL <n> CHECKS PASSED` (n ≈ 20; two checks may print `skip` if the dev DB lacks the sample data — investigate if so, since the fresh production pull should have both).

- [ ] **Step 3: Also re-run the internal API verify script (regression)**

```bash
bin/rails runner lib/scripts/api_verify.rb
```

Expected: ALL 52 CHECKS PASSED.

- [ ] **Step 4: Commit**

```bash
git add lib/scripts/public_api_verify.rb
git commit -m "Add integration verify script for public API"
```

---

### Task 10: Documentation

**Files:**
- Create: `docs/PUBLIC_API.md`
- Modify: `docs/API_PLAN.md` (future-phases section)
- Modify: `docs/SCHEMA.md` (add ApiToken; note touch behavior on SocialMediaAccount/PersonParty)
- Modify: `docs/ARCHITECTURE.md` (new controllers)
- Modify: `docs/FEATURES.md` (admin token management)
- Modify: `app/views/admin/guide/show.html.erb` (token management section + TOC entry)
- Modify: `CLAUDE.md` (Internal API section: mention public API)

**Interfaces:**
- Consumes: final shapes/filters from Tasks 2–8 — **verify each documented example against the running code** (run the curl examples against `bin/dev` or check against the request specs) before committing.

- [ ] **Step 1: Write `docs/PUBLIC_API.md`**

Full content (adjust only if implementation diverged):

````markdown
# Candidata Public API (v1)

Read-only JSON API for external services that need ground truth about
candidates, election winners, and current officeholders.

Base URL: `https://candidata.space/api/v1`

## Authentication

Every request needs a bearer token (issued by a Candidata admin at
`/admin/api_tokens` — one token per consumer service):

```bash
curl -H "Authorization: Bearer cnd_live_..." \
  "https://candidata.space/api/v1/officeholders?state=TX&district=14&office_category=U.S.+Representative"
```

Missing/invalid/revoked token → `401 {"error": …, "code": "UNAUTHORIZED"}`.
Rate limit: 300 requests/minute per token (429 `RATE_LIMITED` beyond that).

## Conventions

- Success: `{"data": …, "meta": …}`. Errors: `{"error": …, "code": "NOT_FOUND" | "INVALID_PARAM" | "UNAUTHORIZED" | "RATE_LIMITED"}`.
- Pagination on every list: `?page=` (default 1) and `?per_page=` (default 25, max 500).
  `meta`: `total`, `page`, `per_page`, `total_pages`, `has_next_page`, `has_previous_page`.
  Rows are ordered by `id` — stable across pages.
- Incremental sync: every list accepts `?updated_since=<ISO8601>` and returns
  rows whose own `updated_at` is at or after that time.
- People are identified by `person_uuid` (stable). Numeric `id`s appear in
  payloads for reference but `person_uuid` is the key to store.
- Social media accounts in payloads are **verified, active accounts only**
  (Candidata's human verification workflow) — that's the ground-truth guarantee.

## Endpoints

### `GET /api/v1/officeholders`

Who holds office. **Returns current officeholders by default**; pass
`current=false` to include historical rows.

| Param | Meaning |
|---|---|
| `state` | Office state, e.g. `TX` |
| `level` | `federal` / `state` / `local` |
| `branch` | `executive` / `legislative` / `judicial` |
| `office_category` | e.g. `U.S. Senator`, `U.S. Representative`, `Governor`, `State Representative` |
| `body_name` | e.g. `U.S. House of Representatives` |
| `district` | District number (combine with `chamber` and/or `office_category` to disambiguate) |
| `chamber` | District chamber, e.g. `upper` / `lower` |
| `party` | Officeholder's primary party, by name or abbreviation (`Democratic` or `D`) |
| `current` | `false` to include former officeholders |
| `updated_since` | ISO8601 |

Row shape:

```json
{
  "id": 123,
  "start_date": "2025-01-03", "end_date": null,
  "elected_year": 2024, "appointed": false, "current": true,
  "updated_at": "2026-06-01T12:00:00Z",
  "person": { … see Person shape … },
  "office": {
    "id": 45, "title": "U.S. Representative TX-14",
    "level": "federal", "branch": "legislative", "role": "legislatorLowerBody",
    "office_category": "U.S. Representative", "body_name": "U.S. House of Representatives",
    "state": "TX", "seat": null, "county": null, "jurisdiction": null, "ocdid": "…",
    "district": {"state": "TX", "district_number": 14, "chamber": "lower", "level": "…", "ocdid": "…"}
  }
}
```

Examples:

```bash
# Who is the TX-14 U.S. rep?
…/officeholders?state=TX&office_category=U.S.+Representative&district=14

# Both current U.S. senators from New York
…/officeholders?state=NY&office_category=U.S.+Senator

# All current Democratic state legislators in Georgia
…/officeholders?state=GA&level=state&branch=legislative&party=D
```

### `GET /api/v1/candidates`

Who is running / ran / won.

| Param | Meaning |
|---|---|
| `year` | Contest year, e.g. `2026` |
| `state` | Ballot state |
| `office_category` | As above |
| `district` / `chamber` | Via the contest's office district |
| `party` | Matches the candidate's `party_at_time` (exact string, e.g. `Democratic`) |
| `outcome` | `won` / `lost` / `pending` / `withdrawn` / `unknown` / `advanced` |
| `winners` | `true` → outcome is `won` OR `advanced` (advanced = unopposed advancement to the general; Candidata counts it as a winning outcome) |
| `incumbent` | `true` = incumbents running; `false` = challengers |
| `updated_since` | ISO8601 |

Row shape: `{id, outcome, winner, incumbent, party_at_time, tally, updated_at,
person: {…}, contest: {id, name, contest_type, party, date, office: {…office shape…},
ballot: {id, state, date, election_type, party, year, election: {id, state, date, election_type, year}}}}`.

```bash
# All 2026 GA primary winners
…/candidates?year=2026&state=GA&winners=true

# Republican challengers in TX house districts
…/candidates?state=TX&party=Republican&incumbent=false&chamber=lower
```

### `GET /api/v1/people` and `GET /api/v1/people/:person_uuid`

The bulk-sync backbone and stable-ID lookup.

| Param (index) | Meaning |
|---|---|
| `state` | `state_of_residence` |
| `q` | Name search (space-separated terms, each matched against first/middle/last) |
| `updated_since` | ISO8601 — **includes social-account and party changes** (they touch the person) |

Person shape (also embedded in officeholders/candidates rows, minus
`current_offices`/`candidacies` which only the people endpoints include):

```json
{
  "id": 9876, "person_uuid": "6f0c…",
  "first_name": "Kathy", "middle_name": null, "last_name": "Hochul", "suffix": null,
  "full_name": "Kathy Hochul", "state_of_residence": "NY",
  "gender": "Female", "race": "White",
  "photo_url": "…", "wikipedia_id": "Kathy_Hochul",
  "websites": {"official": "…", "campaign": "…", "personal": null},
  "party": {"name": "Democratic", "abbreviation": "D"},
  "parties": [{"name": "Democratic", "abbreviation": "D", "is_primary": true}],
  "social_media_accounts": [
    {"platform": "Twitter", "handle": "GovKathyHochul",
     "url": "https://twitter.com/GovKathyHochul", "channel_type": "Official Office"}
  ],
  "updated_at": "2026-06-01T12:00:00Z",
  "current_offices": [{…office shape…, "start_date": "2021-08-24", "elected_year": null}],
  "candidacies": [{"id": 4, "outcome": "won", "winner": true, "incumbent": true,
                   "party_at_time": "Democratic", "tally": null,
                   "contest": {"id": 7, "name": "…", "contest_type": "primary",
                                "party": "Democratic", "date": "2026-06-23"}}]
}
```

## Mirroring the dataset (sync recipe)

Initial load — page through each list with `per_page=500`:

```
GET /api/v1/people?per_page=500&page=1..N
GET /api/v1/officeholders?per_page=500&page=1..N        (current only)
GET /api/v1/candidates?per_page=500&page=1..N
```

Then on a schedule (store the timestamp you started each sync at, reuse it as
the next `updated_since` — overlap is fine, the sync is idempotent by id):

```
GET /api/v1/people?updated_since=<last_sync>&per_page=500
GET /api/v1/officeholders?updated_since=<last_sync>&per_page=500&current=false
GET /api/v1/candidates?updated_since=<last_sync>&per_page=500
```

Person-level changes (new verified social, party change, demographic fix)
surface via `/people`'s `updated_since`. Officeholder/candidate `updated_since`
covers changes to those rows themselves (outcomes, end dates). Pass
`current=false` on the officeholders delta so you see terms that *ended*.

## Guarantees & caveats

- v1 shapes only change additively; breaking changes mean `/api/v2`.
- Socials: verified + active only. If an account is unverified, inactive, or
  awaiting review, it is absent from this API.
- `advanced` outcomes count as winners (see `winners=true`) — an unopposed
  primary advancement is a nomination.
- Data completeness varies by state and cycle; see `/help/coverage` in-app.
````

- [ ] **Step 2: Update the other docs**

`docs/API_PLAN.md` — replace the line `- Public read API with token auth + rate limiting` in **Future phases** with a new section above Future phases:

```markdown
## Public API (implemented)

`/api/v1/*` — read-only, Bearer-token auth (`ApiToken` model, admin-managed at
`/admin/api_tokens`), 300 req/min/token. Endpoints: officeholders, candidates,
people (+ show by `person_uuid`); all paginated (max 500) with `updated_since`
incremental sync. Full consumer docs: `docs/PUBLIC_API.md`. Verified by
`bin/rails runner lib/scripts/public_api_verify.rb`.
```

and remove that bullet from Future phases.

`docs/SCHEMA.md` — add an `ApiToken` section following the doc's existing model-section format (attributes: name, token_digest [unique, SHA-256], created_by_id → users, last_used_at, revoked_at; scope `active`; class methods `generate!`, `authenticate`, instance `revoke!`, `revoked?`, `touch_last_used!`). In the SocialMediaAccount and PersonParty sections, note `belongs_to :person, touch: true` (public-API incremental sync relies on it).

`docs/ARCHITECTURE.md` — under the controllers section, add `Api::V1::BaseController` (+ Serializers module, token auth, rate limiting) and the three v1 controllers, plus `Admin::ApiTokensController`, each with a one-line purpose, following the doc's existing format.

`docs/FEATURES.md` — under admin features, add: API token management (`/admin/api_tokens`): create/revoke bearer tokens for the public read API; token plaintext shown once at creation.

`CLAUDE.md` — in the `## Internal API (/api/*)` section, append: "The **public read API** lives at `/api/v1/*` (Bearer-token auth via ApiToken, admin-managed; see `docs/PUBLIC_API.md`); verify with `bin/rails runner lib/scripts/public_api_verify.rb`."

- [ ] **Step 3: Update the admin guide**

In `app/views/admin/guide/show.html.erb`: add a TOC entry and a numbered section (match the file's existing section markup — read the file first and copy the structure of a short existing section) covering: what the public API is (link `docs/PUBLIC_API.md` by name), creating a token at `/admin/api_tokens` (one per consumer, copy the plaintext immediately — it is never shown again), monitoring last-used, and revoking (consumers get 401s immediately, other tokens unaffected).

- [ ] **Step 4: Verify docs against reality, run everything, commit**

```bash
bundle exec rspec && bin/rails runner lib/scripts/public_api_verify.rb && bin/rails runner lib/scripts/api_verify.rb
git add docs/PUBLIC_API.md docs/API_PLAN.md docs/SCHEMA.md docs/ARCHITECTURE.md docs/FEATURES.md app/views/admin/guide/show.html.erb CLAUDE.md
git commit -m "Document public API v1 (consumer docs, schema, architecture, admin guide)"
```

Expected: full suite green, both verify scripts pass.

---

## Post-plan notes (not tasks)

- **Deploy**: production is currently 2 commits behind GitHub even before this work. Deploying this feature = `git push origin main && git push heroku main`, then `heroku run bin/rails db:migrate --app candidata` (new `api_tokens` table). Take `heroku pg:backups:capture --app candidata` first (repo rule for DB-writing commands).
- **First token**: after deploy, create the first real token in `/admin/api_tokens` on production and hand it to the first consumer.
- **Not in v1** (spec-listed omissions): elections/contests/offices endpoints, CSV export, webhooks. Add inside v1 additively if consumers ask.
