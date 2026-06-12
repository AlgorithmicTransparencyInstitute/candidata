FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "Test-pass-123!" }
    name { "Test User" }
    role { "researcher" }

    trait :admin do
      role { "admin" }
    end
  end

  factory :person do
    sequence(:first_name) { |n| "First#{n}" }
    sequence(:last_name) { |n| "Last#{n}" }
    state_of_residence { "NY" }
  end

  factory :assignment do
    user
    person
    association :assigned_by, factory: [:user, :admin]
    task_type { "data_validation" }
    status { "in_progress" }

    trait :data_collection do
      task_type { "data_collection" }
    end

    trait :secondary_verification do
      task_type { "secondary_verification" }
    end
  end

  factory :social_media_account do
    person
    platform { "Twitter" }
    channel_type { "Campaign" }
    research_status { "not_started" }

    trait :entered do
      research_status { "entered" }
      sequence(:handle) { |n| "handle#{n}" }
      url { "https://twitter.com/#{handle}" }
      entered_at { 1.hour.ago }
    end

    trait :verified do
      research_status { "verified" }
      verified { true }
      sequence(:handle) { |n| "verified#{n}" }
      url { "https://twitter.com/#{handle}" }
      verified_at { 1.hour.ago }
    end
  end
end
