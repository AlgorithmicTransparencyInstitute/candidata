FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { 'password123' }
    name { Faker::Name.name }
    role { 'researcher' }

    trait :admin do
      role { 'admin' }
    end

    trait :researcher do
      role { 'researcher' }
    end

    trait :invited do
      invitation_token { Devise.friendly_token }
      invitation_created_at { 2.days.ago }
      invitation_sent_at { 2.days.ago }
    end

    trait :with_oauth_google do
      provider { 'google_oauth2' }
      sequence(:uid) { |n| "google-#{n}" }
    end

    trait :with_oauth_entra do
      provider { 'entra_id' }
      sequence(:uid) { |n| "entra-#{n}" }
    end
  end
end
