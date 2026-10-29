FactoryBot.define do
  factory :rehandling_request do
    movement_pass { association :movement_pass, :standalone, movement_type: "salida" }
    container { movement_pass.container }
  end
end
