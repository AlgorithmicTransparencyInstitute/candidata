FactoryBot.define do
  factory :person do
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }

    trait :with_uuid do
      sequence(:person_uuid) { |n| "uuid-#{n}" }
    end

    trait :with_airtable_id do
      sequence(:airtable_id) { |n| "rec#{n}AIRTABLE" }
    end

    trait :male do
      gender { 'Male' }
    end

    trait :female do
      gender { 'Female' }
    end

    trait :with_details do
      middle_name { Faker::Name.middle_name }
      suffix { 'Jr.' }
      gender { 'Male' }
      state_of_residence { 'CA' }
    end
  end
end
