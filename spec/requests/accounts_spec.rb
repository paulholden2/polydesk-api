require 'rails_helper'

RSpec.describe 'Accounts', type: :request do
  describe 'POST /accounts' do
    it 'creates new account' do
      post '/accounts', params: { account_identifier: 'rspec2',
                                  account_name: 'RSpec 2',
                                  user_name: 'RSpec User 2',
                                  user_email: 'rspec2@polydesk.io',
                                  password: 'password',
                                  password_confirmation: 'password' }
      expect(response).to have_http_status(201)
    end
  end

  describe 'GET /rspec/account' do
    it 'retrieves account information' do
      get '/rspec/account', headers: account_login('rspec', 'rspec@polydesk.io', 'password')
      expect(response).to have_http_status(200)
    end
  end

  describe 'GET /acme/account' do
    it 'blocks restricted account information retrieval' do
      get '/acme/account', headers: account_login('rspec', 'rspec@polydesk.io', 'password')
      expect(response).to have_http_status(403)
    end
  end

  describe 'GET /accounts' do
    it 'retrieves all available accounts' do
      get '/accounts', headers: account_login('rspec', 'rspec@polydesk.io', 'password')
      expect(response).to have_http_status(200)
    end
  end

  describe 'GET /rspec/users' do
    it 'retrieves all account users' do
      get '/rspec/users', headers: account_login('rspec', 'rspec@polydesk.io', 'password')
      expect(response).to have_http_status(200)
    end
  end
end