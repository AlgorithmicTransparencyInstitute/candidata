FactoryBot.define do
  factory :election do
    state { 'CA' }
    date { Date.new(2024, 11, 5) }
    election_type { 'general' }
    year { 2024 }

    trait :primary do
      election_type { 'primary' }
      date { Date.new(2024, 6, 4) }
    end

    trait :special do
      election_type { 'special' }
    end

    trait :upcoming do
      date { 6.months.from_now.to_date }
      year { 6.months.from_now.year }
    end

    trait :past do
      date { 1.year.ago.to_date }
      year { 1.year.ago.year }
    end
  end
end
