FactoryBot.define do
  factory :work_schedule do
    scheduled_for { Date.current }
    master_bl { association :master_bl }
  end
end
