FactoryBot.define do
  factory :cargo_packaging do
    sequence(:code) { |n| "roll#{n}" }
    sequence(:name) { |n| "Rollo #{n}" }
    tracking_mode { "individual" }
    weight_required { true }
    qr_allowed { true }
    active { true }

    trait :pallet do
      code { "pallet" }
      name { "Pallet" }
    end

    trait :box do
      code { "box" }
      name { "Caja" }
      tracking_mode { "aggregate" }
      weight_required { false }
      qr_allowed { false }
    end
  end

  factory :cargo_manifest do
    client

    trait :with_container do
      after(:build) do |manifest|
        master_bl = build(:master_bl, client: manifest.client)
        manifest.container = build(:container, :with_master_bl, master_bl: master_bl)
      end
    end

    trait :confirmed do
      status { "confirmed" }
      confirmed_at { Time.current }
    end
  end

  factory :cargo_item do
    cargo_manifest
    cargo_packaging
    description { "Rollo de acero" }
    quantity { 1 }
    weight_kg { 800 }
  end
end
