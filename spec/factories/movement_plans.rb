FactoryBot.define do
  factory :movement_plan do
    movement_type { "reacomodo" }
    container
    origin_yard_slot { association :yard_slot }
    destination_yard_slot { association :yard_slot }
  end
end
