FactoryBot.define do
  factory :social_media_account do
    association :person
    platform { 'Twitter' }
    channel_type { 'Campaign' }
    research_status { 'not_started' }

    trait :entered do
      research_status { 'entered' }
      sequence(:handle) { |n| "handle#{n}" }
      url { "https://twitter.com/#{handle}" }
      association :entered_by, factory: :user
      entered_at { Time.current }
    end

    trait :not_found do
      research_status { 'not_found' }
      association :entered_by, factory: :user
      entered_at { Time.current }
    end

    trait :verified do
      research_status { 'verified' }
      verified { true }
      sequence(:handle) { |n| "verified_handle#{n}" }
      association :entered_by, factory: :user
      association :verified_by, factory: :user
      entered_at { 1.day.ago }
      verified_at { Time.current }
    end

    trait :rejected do
      research_status { 'rejected' }
      association :verified_by, factory: :user
      verified_at { Time.current }
    end

    trait :revised do
      research_status { 'revised' }
      verified { false }
    end

    trait :pre_populated do
      pre_populated { true }
      research_status { 'not_started' }
    end

    trait :inactive do
      account_inactive { true }
    end

    trait :facebook do
      platform { 'Facebook' }
    end

    trait :instagram do
      platform { 'Instagram' }
    end

    trait :youtube do
      platform { 'YouTube' }
    end
  end
end
