FactoryBot.define do
  factory :office do
    sequence(:title) { |n| "Office #{n}" }
    level { 'federal' }
    branch { 'legislative' }

    trait :us_senate do
      title { 'U.S. Senator' }
      level { 'federal' }
      branch { 'legislative' }
      role { 'legislatorUpperBody' }
    end

    trait :us_house do
      title { 'U.S. Representative' }
      level { 'federal' }
      branch { 'legislative' }
      role { 'legislatorLowerBody' }
    end

    trait :governor do
      title { 'Governor' }
      level { 'state' }
      branch { 'executive' }
      role { 'headOfGovernment' }
    end

    trait :state_rep do
      title { 'State Representative' }
      level { 'state' }
      branch { 'legislative' }
      role { 'legislatorLowerBody' }
    end

    trait :judicial do
      branch { 'judicial' }
      role { 'highestCourtJudge' }
    end

    trait :local do
      level { 'local' }
    end
  end
end
