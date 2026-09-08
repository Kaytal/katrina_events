FactoryBot.define do
  factory :page do
    sequence(:slug) { |n| "page-#{n}" }
    title { "A page" }
    body { "## A heading\n\nSome copy." }
    meta_description { "A short description." }
    published_at { 1.day.ago }

    trait :draft do
      published_at { nil }
    end

    trait :scheduled do
      published_at { 1.day.from_now }
    end
  end
end
