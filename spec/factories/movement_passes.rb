FactoryBot.define do
  factory :movement_pass_vehicle do
    role { "principal" }
    company_name { "Transportes Golfo" }
    operator_name { "Juan Pérez" }
    sequence(:plate) { |n| "ABC#{n.to_s.rjust(3, '0')}" }
    unit_type { "sencillo" }
  end

  factory :movement_pass do
    container_assignment { association :container_assignment, strategy: :create }
    container { container_assignment&.container }
    movement_type { container_assignment&.operation || "ingreso" }

    after(:build) do |pass|
      roles = pass.movement_type == "traspaleo" ? MovementPassVehicle::ROLES : %w[principal]
      roles.each { |role| pass.vehicles << build(:movement_pass_vehicle, role: role, movement_pass: pass) if pass.vehicle(role).nil? }
    end

    trait :standalone do
      container_assignment { nil }
      container { association :container }
      movement_type { "ingreso" }
      load_status { "lleno" }
    end
  end
end
