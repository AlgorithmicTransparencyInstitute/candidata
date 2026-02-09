FactoryBot.define do
  factory :officeholder do
    association :person
    association :office
    start_date { Date.new(2023, 1, 1) }

    trait :current do
      end_date { nil }
    end

    trait :former do
      end_date { 6.months.ago.to_date }
    end

    trait :with_term do
      start_date { Date.new(2023, 1, 3) }
      end_date { Date.new(2025, 1, 3) }
      elected_year { 2022 }
    end

    trait :appointed do
      appointed { true }
    end
  end
end
