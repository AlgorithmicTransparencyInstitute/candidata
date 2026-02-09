FactoryBot.define do
  factory :contest do
    date { Date.new(2024, 11, 5) }
    contest_type { 'general' }
    association :office
    association :ballot

    trait :primary do
      contest_type { 'primary' }
      party { 'Democratic' }
    end

    trait :special do
      contest_type { 'special' }
    end
  end
end
