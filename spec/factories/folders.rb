FactoryBot.define do
  factory :folder do
    name { 'RSpec Folder' }
  end

  factory :subfolder, class: Folder do
    association :folder, factory: :folder
    name { 'RSPec Subfolder' }
  end

  factory :versioned_folder, parent: :folder do
    after(:create) do |folder, evaluator|
      folder.name = 'RSpec Versioned Folder'
      folder.save!
    end
  end

  factory :discarded_folder, parent: :folder do
    before(:create) do |folder, evaluator|
      folder.discard!
    end
  end
end
