FactoryBot.define do
  factory :person_party do
    association :person
    association :party
    is_primary { false }

    trait :primary do
      is_primary { true }
    end
  end
end
