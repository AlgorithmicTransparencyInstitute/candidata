FactoryBot.define do
  factory :body do
    sequence(:name) { |n| "Body #{n}" }
    level { 'federal' }
    branch { 'legislative' }
    country { 'US' }

    trait :state_level do
      level { 'state' }
    end

    trait :executive do
      branch { 'executive' }
    end

    trait :with_parent do
      association :parent_body, factory: :body
    end
  end
end
