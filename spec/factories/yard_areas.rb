FactoryBot.define do
  factory :yard_area do
    yard_block
    client
    sequence(:code) { |n| "AREA#{n}" }
    sequence(:name) { |n| "Área #{n}" }
  end

  factory :yard_area_section do
    yard_area
    sequence(:name) { |n| "Sección #{n}" }
  end
end
