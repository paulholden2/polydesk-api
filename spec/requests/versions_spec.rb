require 'rails_helper'

RSpec.describe 'Versions', type: :request do
  describe 'GET /rspec/documents/:id/versions' do
    let!(:document) { create :document }
    let!(:permission) { create :permission, code: :document_show, account_user: AccountUser.last }
    it 'retrieves all document versions' do
      document.name = 'New document name'
      document.save!
      get "/rspec/documents/#{document.id}/versions", headers: rspec_session
      expect(response).to have_http_status(200)
    end
  end

  describe 'GET /rspec/folders/:id/versions' do
    let!(:folder) { create :folder }
    it 'retrieves all folder versions' do
      folder.name = 'New folder name'
      folder.save!
      get "/rspec/folders/#{folder.id}/versions", headers: rspec_session
      expect(response).to have_http_status(200)
    end
  end
end
