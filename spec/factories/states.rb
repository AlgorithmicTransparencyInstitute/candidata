FactoryBot.define do
  factory :state do
    sequence(:name) { |n| "State #{n}" }
    sequence(:abbreviation) { |n| "S#{n.to_s.rjust(2, '0')}" }
    state_type { 'state' }

    trait :territory do
      state_type { 'territory' }
    end

    trait :federal_district do
      state_type { 'federal_district' }
    end

    trait :california do
      name { 'California' }
      abbreviation { 'CA' }
      fips_code { '06' }
    end

    trait :texas do
      name { 'Texas' }
      abbreviation { 'TX' }
      fips_code { '48' }
    end
  end
end
