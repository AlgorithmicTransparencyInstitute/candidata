FactoryBot.define do
  factory :ballot do
    state { 'CA' }
    date { Date.new(2024, 11, 5) }
    election_type { 'general' }
    year { 2024 }

    trait :primary do
      election_type { 'primary' }
      party { 'Democratic' }
    end

    trait :special do
      election_type { 'special' }
    end

    trait :with_election do
      association :election
    end
  end
end
