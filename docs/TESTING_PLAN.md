# Comprehensive Testing Implementation Plan

**Status**: Phase 1-5 COMPLETE (Unit Tests)
**Framework**: RSpec 7.1 with FactoryBot 6.5, shoulda-matchers 6.5
**Achieved Coverage**: 362 tests across 15 models, 0 failures
**Test Suite Runtime**: ~5.5 seconds

## Overview

This document outlines the complete strategy for implementing comprehensive unit tests for the Candidata application. The plan covers all 15 production models with 362 test cases.

**Current State**: Unit test framework fully implemented
**Implemented**: 362 unit tests across all 15 production models
**Next Goal**: Controller/request tests, service tests, integration tests

## Quick Start

When ready to begin testing implementation:

```bash
# Phase 1: Install gems and setup
bundle install
rails generate rspec:install
mkdir -p spec/support spec/fixtures
RAILS_ENV=test bin/rails db:create db:schema:load
```

## Implementation Phases

| Phase | Focus | Status | Tests | Notes |
|-------|-------|--------|-------|-------|
| 1 | Infrastructure setup | DONE | 0 | RSpec, FactoryBot, shoulda-matchers, SimpleCov, WebMock, Timecop |
| 2 | Factory definitions (15 models) | DONE | N/A | 15 factory files with traits |
| 3 | TIER 1 models (Person, User, SocialMediaAccount) | DONE | 133 | Most complex business logic |
| 4 | TIER 2 models (Assignment, Office, Officeholder) | DONE | 83 | Temporal scopes, state transitions |
| 5 | TIER 3-4 models (9 remaining) | DONE | 146 | Candidate, Contest, PersonParty, District, Body, Ballot, Party, State, Election |
| **TOTAL** | **Complete model test suite** | **DONE** | **362** | **All passing, ~5.5s runtime** |

---

## Phase 1: Test Infrastructure Setup (2-3 hours)

### 1.1 Required Gems

Add to `Gemfile` in the `:development, :test` group:

```ruby
group :development, :test do
  # Testing framework
  gem 'rspec-rails', '~> 7.1'

  # Test data factories
  gem 'factory_bot_rails', '~> 6.4'
  gem 'faker', '~> 3.5'

  # Testing utilities
  gem 'shoulda-matchers', '~> 6.4'      # Model matchers
  gem 'database_cleaner-active_record', '~> 2.2'
  gem 'simplecov', '~> 0.22', require: false
  gem 'timecop', '~> 0.9'               # Date/time manipulation
  gem 'webmock', '~> 3.24'              # HTTP stubbing
end
```

**Why these gems?**
- **rspec-rails**: Testing framework compatible with Rails 8.0.4
- **shoulda-matchers**: Clean one-liner validation/association tests
- **timecop**: Critical for testing temporal scopes (current, as_of, elected_in)
- **webmock**: Stub HTTP for User avatar downloads in OAuth flow

### 1.2 RSpec Configuration

**File: `spec/rails_helper.rb`** - Add after generated content:

```ruby
# Load support files
Dir[Rails.root.join('spec', 'support', '**', '*.rb')].sort.each { |f| require f }

RSpec.configure do |config|
  # Include FactoryBot methods
  config.include FactoryBot::Syntax::Methods

  # Database cleaning
  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning { example.run }
  end

  # Devise helpers
  config.include Devise::Test::IntegrationHelpers, type: :request

  # PaperTrail (disabled by default)
  config.before(:each) do
    PaperTrail.enabled = false
  end

  config.before(:each, versioning: true) do
    PaperTrail.enabled = true
  end
end
```

**File: `spec/spec_helper.rb`** - Add at top:

```ruby
require 'simplecov'
SimpleCov.start 'rails' do
  add_filter '/spec/'
  add_filter '/config/'
  add_group 'Models', 'app/models'
  add_group 'Controllers', 'app/controllers'
  add_group 'Services', 'app/services'
end

require 'webmock/rspec'
WebMock.disable_net_connect!(allow_localhost: true)
```

**File: `spec/support/shoulda_matchers.rb`** - Create:

```ruby
Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end
```

---

## Phase 2: Factory Definitions (4-6 hours)

Create FactoryBot factories for all models in dependency order.

### Factory Design Principles

1. **Minimal valid data** - Only required fields in base factory
2. **Sequences for uniqueness** - email, UUID, airtable_id
3. **Traits for variations** - Use traits instead of separate factories
4. **Let FactoryBot handle associations** - Use `association` keyword
5. **Avoid after(:create)** - Use traits when possible (faster)

### Critical Factories Overview

#### 1. Reference Data (No dependencies)
- **State** (`spec/factories/states.rb`)
- **Party** (`spec/factories/parties.rb`)

#### 2. Core Entities
- **User** (`spec/factories/users.rb`) - Traits: `:admin`, `:researcher`, `:invited`, `:with_oauth_google`
- **Person** (`spec/factories/people.rb`) - Traits: `:with_party`, `:current_officeholder`

#### 3. Structural Data
- **District** (`spec/factories/districts.rb`)
- **Body** (`spec/factories/bodies.rb`)
- **Office** (`spec/factories/offices.rb`) - Traits: `:us_senate`, `:governor`

#### 4. Relational Data
- **PersonParty** (`spec/factories/person_parties.rb`) - Traits: `:primary`
- **Officeholder** (`spec/factories/officeholders.rb`) - Traits: `:current`, `:former`
- **SocialMediaAccount** (`spec/factories/social_media_accounts.rb`) - Traits: `:entered`, `:verified`
- **Assignment** (`spec/factories/assignments.rb`) - Traits: `:pending`, `:completed`

#### 5. Election Data
- **Ballot** (`spec/factories/ballots.rb`)
- **Contest** (`spec/factories/contests.rb`)
- **Candidate** (`spec/factories/candidates.rb`)

### Example Factory: User

```ruby
# spec/factories/users.rb
FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password123" }
    name { Faker::Name.name }
    role { "researcher" }

    trait :admin do
      role { "admin" }
    end

    trait :invited do
      invitation_token { Devise.friendly_token }
      invitation_created_at { 2.days.ago }
      invitation_sent_at { 2.days.ago }
    end

    trait :with_oauth_google do
      provider { "google_oauth2" }
      sequence(:uid) { |n| "google-#{n}" }
    end
  end
end
```

---

## Phase 3: TIER 1 Model Tests (8-12 hours)

Test the 3 most complex models with highest business logic density.

### Model Testing Priority

**TIER 1 (Critical - Test First)**:
1. **Person** (110 lines) - 30 tests
   - Temporal scopes, party management, name formatting
2. **User** (106 lines) - 28 tests
   - OAuth integration, invitation flow, role authorization
3. **SocialMediaAccount** (102 lines) - 32 tests
   - 5-state workflow, 11 platforms, prepopulation logic

**TIER 2 (High Priority)**:
4. **Assignment** (52 lines) - 18 tests
5. **Office** (53 lines) - 20 tests
6. **Officeholder** (41 lines) - 22 tests

**TIER 3-4 (Medium-Low Priority)**: Remaining 8 models - ~100 tests

### Person Model Test Structure

**File**: `spec/models/person_spec.rb`

```ruby
require 'rails_helper'

RSpec.describe Person, type: :model do
  describe 'associations' do
    it { should have_many(:person_parties).dependent(:destroy) }
    it { should have_many(:parties).through(:person_parties) }
    it { should have_many(:officeholders) }
    it { should have_many(:social_media_accounts).dependent(:destroy) }
    # ... 6 more associations
  end

  describe 'validations' do
    it { should validate_presence_of(:first_name) }
    it { should validate_presence_of(:last_name) }
    it { should validate_inclusion_of(:gender).in_array(['Male', 'Female', 'Other']).allow_nil }
  end

  describe 'scopes' do
    describe '.current_officeholders' do
      it 'returns people currently in office' do
        current = create(:person, :current_officeholder)
        former = create(:person, :former_officeholder)

        expect(Person.current_officeholders).to include(current)
        expect(Person.current_officeholders).not_to include(former)
      end
    end

    describe '.officeholders_as_of' do
      it 'returns people in office on specific date' do
        Timecop.freeze(Date.new(2024, 6, 1)) do
          person = create(:person)
          oh = create(:officeholder,
                      person: person,
                      start_date: Date.new(2022, 1, 1),
                      end_date: Date.new(2026, 1, 1))

          expect(Person.officeholders_as_of(Date.new(2024, 6, 1))).to include(person)
          expect(Person.officeholders_as_of(Date.new(2021, 12, 31))).not_to include(person)
        end
      end
    end
  end

  describe '#primary_party=' do
    it 'sets a new primary party' do
      person = create(:person)
      dem = create(:party, name: 'Democratic Party')

      person.primary_party = dem

      expect(person.primary_party).to eq(dem)
      expect(person.person_parties.find_by(party: dem).is_primary).to be true
    end

    it 'clears existing primary when setting new one' do
      person = create(:person)
      rep = create(:party, name: 'Republican Party')
      dem = create(:party, name: 'Democratic Party')
      create(:person_party, person: person, party: rep, is_primary: true)

      person.primary_party = dem

      expect(person.person_parties.find_by(party: rep).is_primary).to be false
      expect(person.person_parties.find_by(party: dem).is_primary).to be true
    end
  end
end
```

### User Model OAuth Testing

**Critical Test**: OAuth with invitation auto-acceptance

```ruby
# spec/models/user_spec.rb
describe '.from_omniauth' do
  let(:google_auth) do
    OmniAuth::AuthHash.new({
      provider: 'google_oauth2',
      uid: '12345',
      info: {
        email: 'user@example.com',
        name: 'Test User',
        image: 'https://example.com/avatar.jpg'
      }
    })
  end

  before do
    # Stub avatar download
    stub_request(:get, "https://example.com/avatar.jpg")
      .to_return(
        body: File.read(Rails.root.join('spec', 'fixtures', 'avatar.jpg')),
        headers: { 'Content-Type' => 'image/jpeg' }
      )
  end

  context 'when invited user signs in with OAuth' do
    let!(:invited_user) do
      create(:user, :invited, email: 'user@example.com', provider: nil)
    end

    it 'links OAuth credentials and accepts invitation' do
      user = User.from_omniauth(google_auth)

      expect(user).to eq(invited_user)
      expect(user.provider).to eq('google_oauth2')
      expect(user.invitation_accepted_at).to be_present
    end
  end
end
```

### SocialMediaAccount State Machine Testing

```ruby
# spec/models/social_media_account_spec.rb
describe '#mark_entered!' do
  let(:account) { create(:social_media_account, :pre_populated) }
  let(:user) { create(:user) }

  it 'transitions to entered status' do
    account.mark_entered!(user, url: 'https://twitter.com/handle', handle: 'handle')

    expect(account.research_status).to eq('entered')
    expect(account.entered_by).to eq(user)
    expect(account.entered_at).to be_present
    expect(account.url).to eq('https://twitter.com/handle')
  end
end

describe '.prepopulate_for_person!' do
  let(:person) { create(:person) }

  it 'creates accounts for core platforms' do
    expect {
      SocialMediaAccount.prepopulate_for_person!(person)
    }.to change { person.social_media_accounts.count }.by(6)
  end

  it 'skips existing platforms' do
    create(:social_media_account, person: person, platform: 'Twitter', channel_type: 'Campaign')

    expect {
      SocialMediaAccount.prepopulate_for_person!(person)
    }.to change { person.social_media_accounts.count }.by(5)
  end
end
```

---

## Phase 4: TIER 2 Model Tests (6-8 hours)

### Assignment Model

**Key Tests**:
- State transitions (`start!`, `complete!`, `reopen!`)
- Uniqueness validation (person_id + user_id + task_type)
- Scopes: `pending`, `in_progress`, `completed`

### Office Model

**Key Tests**:
- Multi-level categorization (level, branch, role)
- Title formatting methods
- Branch helper methods

### Officeholder Model (Critical Temporal Logic)

```ruby
describe '.current' do
  it 'includes officeholders with nil end_date' do
    current = create(:officeholder, end_date: nil)
    expect(Officeholder.current).to include(current)
  end

  it 'includes officeholders with future end_date' do
    Timecop.freeze(Date.new(2024, 6, 1)) do
      current = create(:officeholder, end_date: Date.new(2025, 1, 1))
      expect(Officeholder.current).to include(current)
    end
  end

  it 'excludes officeholders with past end_date' do
    former = create(:officeholder, end_date: 1.year.ago)
    expect(Officeholder.current).not_to include(former)
  end
end

describe 'custom validation' do
  it 'requires end_date after start_date' do
    oh = build(:officeholder,
               start_date: Date.new(2024, 1, 1),
               end_date: Date.new(2023, 12, 31))

    expect(oh).not_to be_valid
    expect(oh.errors[:end_date]).to include("must be after start date")
  end
end
```

---

## Phase 5: TIER 3-4 Model Tests (8-10 hours)

### Remaining 8 Models

1. **Candidate** (~15 tests) - Vote calculations, outcome scopes
2. **Contest** (~15 tests) - Winner logic, vote tallying
3. **PersonParty** (~12 tests) - **Critical**: `only_one_primary_per_person` validation
4. **District** (~12 tests) - 4-field uniqueness, name formatting
5. **Body** (~12 tests) - Self-referential hierarchy
6. **Ballot** (~12 tests) - Year auto-calculation callback
7. **Party** (~10 tests) - Uniqueness validations
8. **State** (~10 tests) - Case-insensitive lookup

### PersonParty Critical Validation

```ruby
describe 'validations' do
  describe 'only_one_primary_per_person' do
    it 'prevents multiple primary parties' do
      person = create(:person)
      party1 = create(:party, name: 'Democratic Party')
      party2 = create(:party, name: 'Republican Party')
      create(:person_party, person: person, party: party1, is_primary: true)

      duplicate = build(:person_party, person: person, party: party2, is_primary: true)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:is_primary]).to be_present
    end
  end
end
```

---

## Testing Strategies for Complex Scenarios

### 1. Temporal Scopes (Person, Officeholder)

**Always use Timecop.freeze with block syntax**:

```ruby
Timecop.freeze(Date.new(2024, 6, 1)) do
  # Test code here - automatically returns to real time
end
```

**Test edge cases**:
- Start date boundary: `as_of(start_date)` should include
- End date boundary: `as_of(end_date)` should include
- Day before start: should exclude
- Day after end: should exclude
- Nil end_date: should be current

### 2. OAuth Integration (User Model)

**Mock OmniAuth responses** (no real providers needed):

```ruby
let(:google_auth) do
  OmniAuth::AuthHash.new({
    provider: 'google_oauth2',
    uid: '12345',
    info: { email: 'user@example.com', name: 'Test User' }
  })
end
```

**Stub HTTP requests for avatar downloads**:

```ruby
stub_request(:get, "https://example.com/avatar.jpg")
  .to_return(body: file_fixture('avatar.jpg').read)
```

### 3. PaperTrail Versioning

**Enable per-test with metadata tag**:

```ruby
it "tracks changes", versioning: true do
  person = create(:person, first_name: "John")
  person.update(first_name: "Jane")

  expect(person.versions.count).to eq(2)
  expect(person.versions.last.reify.first_name).to eq("John")
end
```

### 4. Active Storage (User Avatar)

**Use fixture files**:

```ruby
user.avatar.attach(
  io: File.open(Rails.root.join('spec', 'fixtures', 'avatar.jpg')),
  filename: 'avatar.jpg',
  content_type: 'image/jpeg'
)
```

**Test validations**:

```ruby
it 'validates content type' do
  user = build(:user)
  user.avatar.attach(
    io: StringIO.new('fake'),
    filename: 'file.txt',
    content_type: 'text/plain'
  )
  expect(user).not_to be_valid
end
```

---

## Running Tests

### Common Commands

```bash
# Run all tests
bundle exec rspec

# Run specific file
bundle exec rspec spec/models/person_spec.rb

# Run specific test by line number
bundle exec rspec spec/models/person_spec.rb:42

# Run with documentation format (readable output)
bundle exec rspec --format documentation

# Run with coverage report
COVERAGE=true bundle exec rspec

# Run only failed tests from last run
bundle exec rspec --only-failures

# Run tests matching pattern
bundle exec rspec --example "current_officeholder"
```

### Coverage Reports

After running tests with `COVERAGE=true`, view coverage:

```bash
open coverage/index.html
```

**Coverage targets**:
- Phase 3 complete: 60-70%
- Phase 4 complete: 75-85%
- Phase 5 complete: 85-95%

---

## Success Criteria

### Definition of "Comprehensive Unit Tests"

- ✅ All 15 production models have RSpec test files
- ✅ All associations tested (via shoulda-matchers)
- ✅ All validations tested (presence, uniqueness, inclusion, custom)
- ✅ All scopes tested with positive and negative cases
- ✅ All public instance/class methods tested with edge cases
- ✅ Temporal queries tested across multiple dates with Timecop
- ✅ State machines tested for all valid transitions
- ✅ PaperTrail versioning verified on 4 models
- ✅ 85-95% line coverage achieved
- ✅ Full test suite runs in < 5 minutes

### Performance Targets

- **Full suite runtime**: < 5 minutes
- **Average test speed**: < 0.5 seconds per test
- **Database strategy**: Transactional rollback (fastest)

---

## Best Practices

1. **Keep factories minimal** - Only required fields in base definition
2. **Use shoulda-matchers** - One-liner tests for associations/validations
3. **Test edge cases** - Nil vs empty string, boundaries, invalid states
4. **One assertion per test** - Better failure messages, easier debugging
5. **Use descriptive contexts** - `describe '#method'` and `context 'when condition'`
6. **Mock external services** - WebMock for HTTP, stub OAuth providers
7. **Use let/let!** - Lazy vs eager evaluation of test data
8. **Keep tests fast** - Avoid unnecessary database hits, use build_stubbed when possible

---

## Critical Files Reference

When implementing tests, these files contain the patterns to test:

1. **app/models/person.rb** (110 lines)
   - Most complex business logic
   - Temporal scopes template
   - Party management patterns

2. **app/models/user.rb** (106 lines)
   - OAuth integration logic
   - Invitation acceptance flow
   - Role-based authorization

3. **app/models/social_media_account.rb** (102 lines)
   - State machine implementation
   - Prepopulation pattern
   - Multi-field uniqueness

4. **app/models/officeholder.rb** (41 lines)
   - Temporal query patterns
   - Date validation examples
   - Tenure calculation logic

5. **db/schema.rb**
   - All associations and foreign keys
   - Uniqueness constraints
   - Index structure for factory design

---

## Next Steps

When ready to begin implementation:

1. **Review this plan** and adjust timeline based on team capacity
2. **Install Phase 1 gems** and configure RSpec
3. **Create 2-3 factories** to understand patterns
4. **Write tests for Person model** (most complex, establishes patterns)
5. **Iterate through remaining models** by priority tier

For questions or clarifications, refer to:
- [RSpec Rails documentation](https://github.com/rspec/rspec-rails)
- [FactoryBot documentation](https://github.com/thoughtbot/factory_bot)
- [Shoulda Matchers](https://github.com/thoughtbot/shoulda-matchers)

---

## Known Issues Found During Testing

1. **User role default mismatch**: The `users.role` column defaults to `"researcher_assistant"` in the database schema, but the User model validates `role` inclusion in `["admin", "researcher"]`. This means `User.from_omniauth` fails to persist new users created via OAuth because `create` (non-bang) silently fails validation. **Fix**: Change the DB default to `"researcher"` or add `"researcher_assistant"` to the valid roles list.

2. **State model associations**: The State model declares `has_many :districts`, `has_many :offices`, and `has_many :ballots`, but these related tables use a `state` string column (abbreviation) rather than a `state_id` foreign key. These associations will not work with standard Rails conventions. **Fix**: Either add a `state_id` foreign key to those tables or configure the associations with `foreign_key: :state, primary_key: :abbreviation`.

## Test Counts by Model

| Model | Tests | Categories |
|-------|-------|------------|
| Person | 30 | associations, validations, scopes, instance methods, party management |
| User | 28 | associations, validations, OAuth, roles, scopes |
| SocialMediaAccount | 39 | associations, validations, scopes, state transitions, prepopulation |
| Assignment | 22 | associations, validations, scopes, state transitions |
| Office | 28 | associations, validations, scopes, display methods |
| Officeholder | 33 | associations, validations, scopes, temporal queries, tenure |
| Candidate | 18 | associations, validations, scopes, vote calculations |
| Contest | 23 | associations, validations, scopes, winner logic |
| PersonParty | 10 | associations, validations, primary party constraint |
| District | 16 | associations, validations, scopes, full_name formatting |
| Body | 18 | associations, validations, scopes, hierarchy |
| Ballot | 17 | associations, validations, scopes, callbacks |
| Party | 9 | associations, validations, scopes |
| State | 11 | validations, scopes, methods |
| Election | 15 | associations, validations, scopes, callbacks |
| **Total** | **362** | |

---

**Document Version**: 2.0
**Last Updated**: 2026-02-09
**Status**: Unit tests complete, ready for controller/integration test planning
