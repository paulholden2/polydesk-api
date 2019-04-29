require 'spec_helper'

ENV['RAILS_ENV'] ||= 'test'
require File.expand_path('../../config/environment', __FILE__)

# Prevent database truncation if the environment is production
abort('The Rails environment is running in production mode!') if Rails.env.production?

require 'rspec/rails'

Dir[Rails.root.join('spec', 'support', '**', '*.rb')].each { |f| require f }

# Checks for pending migrations and applies them
begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  puts e.to_s.strip
  exit 1
end

RSpec.configure do |config|
  config.fixture_path = "#{::Rails.root}/spec/fixtures"
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  config.before(:suite) do
    # Database cleanup
    DatabaseCleaner.clean_with :truncation
    DatabaseCleaner.strategy = :transaction
    # Tenant cleanup
    Apartment::Tenant.drop('rspec') rescue nil
    # Account & user creation
    account = Account.create(name: 'RSpec', identifier: 'rspec')
    user = User.create(name: 'RSpec', email: 'rspec@polydesk.io', password: 'password', default_account: account)
    user.confirm
    user.link_account
  end

  config.before(:each) do
    DatabaseCleaner.start
    Apartment::Tenant.switch! 'rspec'
  end

  config.after(:each) do
    Apartment::Tenant.reset
    DatabaseCleaner.clean
  end

  config.include Devise::Test::ControllerHelpers, :type => :controller
  config.include ControllerHelper, :type => :controller
  config.extend ControllerMacros, :type => :controller
  config.include SessionHelper, :type => :request
  config.include ResponseHelper, :type => :controller
  config.include ResponseHelper, :type => :request
end
