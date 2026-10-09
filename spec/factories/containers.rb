FactoryBot.define do
  factory :container do
    sequence(:number) { |n| "TEST#{n.to_s.rjust(7, '0')}" }
    size { 20 }
    container_type { "standard" }
    status { "lleno" }

    trait :with_master_bl do
      master_bl
      status { "activo" }
    end
  end
end
