FactoryBot.define do
  factory :party do
    sequence(:name) { |n| "Party #{n}" }
    sequence(:abbreviation) { |n| "P#{n}" }

    trait :democratic do
      name { 'Democratic Party' }
      abbreviation { 'DEM' }
      ideology { 'center-left' }
    end

    trait :republican do
      name { 'Republican Party' }
      abbreviation { 'REP' }
      ideology { 'center-right' }
    end
  end
end
