FactoryBot.define do
  factory :deconsolidation do
    container { association :container, :with_master_bl }
  end
end
