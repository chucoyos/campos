FactoryBot.define do
  factory :yard_block do
    sequence(:code) { |n| "#{(n % 9) + 1}#{('A'..'Z').to_a[(n / 9) % 26]}" }
    bays { 4 }
    rows { 3 }
    levels { 5 }
  end

  factory :yard_slot do
    yard_block
    bay { 1 }
    row { "A" }
    level { 1 }
  end

  factory :yard_area do
    sequence(:code) { |n| "AREA#{n}" }
    name { "Área" }
    capacity { 72 }
  end
end
