FactoryBot.define do
  factory :container_assignment do
    container { association :container, :with_master_bl }
    carrier
    operation { "ingreso" }
  end
end
