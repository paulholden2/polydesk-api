require 'rails_helper'

RSpec.describe 'Accounts', type: :request do
  describe 'POST /accounts' do
    it 'creates new account with password' do
      post '/accounts', params: {
                          data: {
                            type: 'account',
                            attributes: {
                              account_identifier: 'rspec2',
                              account_name: 'RSpec 2',
                              user_name: 'RSpec User 2',
                              user_email: 'rspec2@polydesk.io',
                              password: 'password',
                              password_confirmation: 'password' } } }
      expect(response).to have_http_status(201)
      expect(json).to be_an('account')
      user = User.find_by!(email: 'rspec2@polydesk.io')
      user.link_account
      account_user = AccountUser.find_by!(user_id: user.id)
      expect(user.valid_password?('password')).to be true
      expect(account_user.role).to eq('administrator')
    end

    it 'creates new account without password' do
      post '/accounts', params: {
                          data: {
                            type: 'account',
                            attributes: {
                              account_identifier: 'rspec3',
                              account_name: 'RSpec 3',
                              user_name: 'RSpec User 3',
                              user_email: 'rspec3@polydesk.io' } } }
      expect(response).to have_http_status(201)
      expect(json).to be_an('account')
      expect(User.last.has_password?).to be false
    end
  end

  describe 'GET /rspec/account' do
    it 'retrieves account information' do
      get '/rspec/account', headers: rspec_session
      expect(response).to have_http_status(200)
      expect(json).to be_an('account')
    end
  end

  describe 'PATCH /rspec/account' do
    context 'with permission' do
      let!(:permission) { create :permission, code: :account_update, account_user: AccountUser.last }
      it 'updates account information' do
        account = Account.last
        patch '/rspec/account', headers: rspec_session,
                                params: {
                                  data: {
                                    id: account.id,
                                    type: 'account',
                                    attributes: {
                                      name: 'RSpec Renamed' } } }.to_json
        expect(response).to have_http_status(200)
        expect(json).to be_an('account')
        expect(account).to have_changed_attributes
        expect(account.reload.name).to eq('RSpec Renamed')
      end
    end

    context 'guest with permission' do
      let!(:guest) { create :rspec_guest, set_permissions: [:account_update] }
      it 'returns authorization error' do
        account = Account.last
        patch '/rspec/account', headers: rspec_session(guest),
                                params: {
                                  data: {
                                    id: account.id,
                                    type: 'account',
                                    attributes: {
                                      name: 'RSpec Renamed' } } }.to_json
        expect(response).to have_http_status(403)
        expect(json).to have_errors
      end
    end

    context 'admin without permission' do
      let!(:admin) { create :rspec_administrator }
      it 'updates account information' do
        account = Account.last
        patch '/rspec/account', headers: rspec_session(admin),
                                params: {
                                  data: {
                                    id: account.id,
                                    type: 'account',
                                    attributes: {
                                      name: 'RSpec Renamed' } } }.to_json
        expect(response).to have_http_status(200)
        expect(json).to be_an('account')
        expect(account).to have_changed_attributes
        expect(account.reload.name).to eq('RSpec Renamed')
      end
    end

    context 'without permission' do
      it 'returns authorization error' do
        account = Account.last
        patch '/rspec/account', headers: rspec_session,
                                params: {
                                  data: {
                                    id: account.id,
                                    type: 'account',
                                    attributes: {
                                      name: 'RSpec Renamed' } } }.to_json
        expect(response).to have_http_status(403)
        expect(json).to have_errors
      end
    end
  end

  # TODO: Create Account factory, verify access is forbidden
  # describe 'GET /acme/account' do
  #   it 'blocks restricted account information retrieval' do
  #     get '/acme/account', headers: rspec_session
  #     expect(response).to have_http_status(404)
  #     expect(json).to have_errors
  #   end
  # end

  describe 'GET /accounts' do
    it 'retrieves all available accounts' do
      get '/accounts', headers: rspec_session
      expect(response).to have_http_status(200)
      expect(json).to be_array_of('account')
    end
  end

  describe 'GET /rspec/users' do
    it 'retrieves all account users' do
      get '/rspec/users', headers: rspec_session
      expect(response).to have_http_status(200)
      expect(json).to be_array_of('user')
    end
  end
end
