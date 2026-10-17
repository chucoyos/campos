FactoryBot.define do
  factory :warehouse_bay do
    sequence(:number) { |n| (n - 1) % 4 + 1 }
  end

  factory :warehouse_slot do
    warehouse_bay { WarehouseBay.find_or_create_by!(number: 1) }
    sequence(:number) { |n| (n - 1) % 16 + 1 }
  end
end
