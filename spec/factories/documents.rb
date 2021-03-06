FactoryBot.define do
  factory :document do
    transient do
      set_skip_background_upload { true }
    end
    content { Rack::Test::UploadedFile.new(Rails.root.join('spec/fixtures/compressed.tracemonkey-pldi-09.pdf')) }
    name { 'RSpec Document' }
    before(:create) do |document, evaluator|
      document.skip_background_upload = evaluator.set_skip_background_upload
    end
  end

  factory :subdocument, parent: :document do
    association :folder, factory: :folder, name: 'RSpec Subdocument Folder'
    content { Rack::Test::UploadedFile.new(Rails.root.join('spec/fixtures/compressed.tracemonkey-pldi-09.pdf')) }
    name { 'RSpec Subdocument' }
  end

  factory :versioned_document, parent: :document do
    content { Rack::Test::UploadedFile.new(Rails.root.join('spec/fixtures/fox.txt')) }
    name { 'RSpec Fox' }
    after(:create) do |document, evaluator|
      document.content = Rack::Test::UploadedFile.new(Rails.root.join('spec/fixtures/dog.txt'))
      document.save!
    end
  end

  factory :discarded_document, parent: :document do
    before(:create) do |document, evaluator|
      document.discard!
    end
  end
end
