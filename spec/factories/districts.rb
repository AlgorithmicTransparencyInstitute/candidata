FactoryBot.define do
  factory :district do
    state { 'CA' }
    level { 'federal' }
    sequence(:district_number) { |n| n }

    trait :congressional do
      level { 'federal' }
      chamber { nil }
    end

    trait :state_senate do
      level { 'state' }
      chamber { 'upper' }
    end

    trait :state_house do
      level { 'state' }
      chamber { 'lower' }
    end

    trait :at_large do
      district_number { 0 }
    end

    trait :local do
      level { 'local' }
    end
  end
end
