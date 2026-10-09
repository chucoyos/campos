FactoryBot.define do
  factory :master_bl do
    sequence(:number) { |n| "MBL#{n.to_s.rjust(6, '0')}" }
    client
  end
end
