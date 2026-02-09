FactoryBot.define do
  factory :candidate do
    association :person
    association :contest
    outcome { 'pending' }
    tally { 0 }

    trait :winner do
      outcome { 'won' }
      tally { 50000 }
    end

    trait :loser do
      outcome { 'lost' }
      tally { 30000 }
    end

    trait :incumbent do
      incumbent { true }
    end

    trait :withdrawn do
      outcome { 'withdrawn' }
    end
  end
end
