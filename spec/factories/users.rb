FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password123" }
    role { "cliente" }

    User::ROLES.each do |name|
      trait(name.to_sym) { role { name } }
    end
  end
end
