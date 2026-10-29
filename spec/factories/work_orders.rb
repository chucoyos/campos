FactoryBot.define do
  factory :work_order do
    movement_type { "ingreso" }
    container { association :container }
    to_yard_slot { association :yard_slot }
    movement_pass { association :movement_pass, :standalone, container: container }
  end
end
