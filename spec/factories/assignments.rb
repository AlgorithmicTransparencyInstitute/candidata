FactoryBot.define do
  factory :assignment do
    association :user
    association :assigned_by, factory: :user
    association :person
    task_type { 'data_collection' }
    status { 'pending' }

    trait :in_progress do
      status { 'in_progress' }
    end

    trait :completed do
      status { 'completed' }
      completed_at { Time.current }
    end

    trait :data_validation do
      task_type { 'data_validation' }
    end
  end
end
