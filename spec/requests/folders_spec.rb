require 'rails_helper'

RSpec.describe 'Folders', type: :request do
  describe 'GET /rspec/folders' do
    context 'with permission' do
      let!(:folder) { create :folder }
      let!(:permission) { create :permission, code: :folder_index, account_user: AccountUser.last }
      it 'retrieves all folders' do
        get '/rspec/folders', headers: rspec_session
        expect(response).to have_http_status(200)
      end
    end

    context 'admin without permission' do
      let!(:admin) { create :rspec_administrator }
      let!(:folder) { create :folder }
      it 'retrieves all folders' do
        get '/rspec/folders', headers: rspec_session(admin)
        expect(response).to have_http_status(200)
      end
    end

    context 'without permission' do
      let!(:folder) { create :folder }
      it 'returns authorization error' do
        get '/rspec/folders', headers: rspec_session
        expect(response).to have_http_status(403)
      end
    end
  end

  describe 'GET /rspec/content' do
    context 'with full permissions' do
      let!(:document) { create :subdocument }
      let!(:document_permission) { create :permission, code: :folder_documents, account_user: AccountUser.last }
      let!(:folder_permission) { create :permission, code: :folder_folders, account_user: AccountUser.last }
      it 'retrieves all content' do
        get '/rspec/content', headers: rspec_session
        expect(response).to have_http_status(200)
      end
    end

    context 'admin without any permissions' do
      let!(:admin) { create :rspec_administrator }
      let!(:document) { create :subdocument }
      it 'retrieves all content' do
        get '/rspec/content', headers: rspec_session(admin)
        expect(response).to have_http_status(200)
      end
    end

    context 'without documents permissions' do
      let!(:document) { create :subdocument }
      let!(:folder_permission) { create :permission, code: :folder_folders, account_user: AccountUser.last }
      it 'returns authorization error' do
        get '/rspec/content', headers: rspec_session
        expect(response).to have_http_status(403)
      end
    end

    context 'without folders permissions' do
      let!(:document) { create :subdocument }
      let!(:document_permission) { create :permission, code: :folder_documents, account_user: AccountUser.last }
      it 'returns authorization error' do
        get '/rspec/content', headers: rspec_session
        expect(response).to have_http_status(403)
      end
    end

    context 'without any permissions' do
      let!(:document) { create :subdocument }
      it 'returns authorization error' do
        get '/rspec/content', headers: rspec_session
        expect(response).to have_http_status(403)
      end
    end
  end

  describe 'POST /rspec/folders' do
    context 'with permission' do
      let!(:permission) { create :permission, code: :folder_create, account_user: AccountUser.last }
      it 'creates new folder' do
        post '/rspec/folders', headers: rspec_session,
                               params: { name: 'RSpec Test' }.to_json
        expect(response).to have_http_status(201)
      end
    end

    context 'guest with permission' do
      let!(:guest) { create :rspec_guest, set_permissions: [:folder_create] }
      it 'creates new folder' do
        post '/rspec/folders', headers: rspec_session(guest),
                               params: { name: 'RSpec Test' }.to_json
        expect(response).to have_http_status(403)
      end
    end

    context 'admin without permission' do
      let!(:admin) { create :rspec_administrator }
      it 'creates new folder' do
        post '/rspec/folders', headers: rspec_session(admin),
                               params: { name: 'RSpec Test' }.to_json
        expect(response).to have_http_status(201)
      end
    end

    context 'without permission' do
      it 'returns authorization error' do
        post '/rspec/folders', headers: rspec_session,
                               params: { name: 'RSpec Test' }.to_json
        expect(response).to have_http_status(403)
      end
    end
  end

  describe 'PATCH/PUT /rspec/folders/1' do
    context 'with permission' do
      let!(:folder) { create :folder, name: 'Initial Name' }
      let!(:permission) { create :permission, code: :folder_update, account_user: AccountUser.last }

      it 'updates folder name' do
        patch "/rspec/folders/#{folder.id}", headers: rspec_session,
                                             params: { name: 'Updated Name' }.to_json
        expect(response).to have_http_status(200)
        expect(folder).to have_changed_attributes
      end

      it 'is idempotent' do
        patch "/rspec/folders/#{folder.id}", headers: rspec_session,
                                             params: {}.to_json
        expect(response).to have_http_status(200)
        expect(folder).not_to have_changed_attributes
      end

      it 'disallows blank folder name' do
        patch "/rspec/folders/#{folder.id}", headers: rspec_session,
                                             params: { name: '' }.to_json
        expect(response).to have_http_status(422)
      end
    end

    context 'guest with permission' do
      let!(:guest) { create :rspec_guest, set_permissions: [:folder_update] }
      let!(:folder) { create :folder, name: 'Initial Name' }
      it 'returns authorization error' do
        patch "/rspec/folders/#{folder.id}", headers: rspec_session(guest),
                                             params: { name: 'Updated Name' }.to_json
        expect(response).to have_http_status(403)
      end
    end

    context 'admin without permission' do
      let!(:admin) { create :rspec_administrator }
      let!(:folder) { create :folder, name: 'Initial Name' }
      it 'updates folder name' do
        patch "/rspec/folders/#{folder.id}", headers: rspec_session(admin),
                                             params: { name: 'Updated Name' }.to_json
        expect(response).to have_http_status(200)
        expect(folder).to have_changed_attributes
      end
    end

    context 'without permission' do
      let!(:folder) { create :folder, name: 'Initial Name' }
      it 'returns authorization error' do
        patch "/rspec/folders/#{folder.id}", headers: rspec_session,
                                             params: { name: 'Updated Name' }.to_json
        expect(response).to have_http_status(403)
      end
    end
  end

  describe 'POST /rspec/folders/1/documents' do
    context 'with all permissions' do
      let!(:folder) { create :folder }
      let!(:document_permission) { create :permission, code: :document_create, account_user: AccountUser.last }
      let!(:folder_permission) { create :permission, code: :folder_add_document, account_user: AccountUser.last }
      it 'uploads a document to a folder' do
        file = Rack::Test::UploadedFile.new(Rails.root.join('spec/fixtures/compressed.tracemonkey-pldi-09.pdf'))
        post "/rspec/folders/#{folder.id}/documents", headers: rspec_session,
                                 params: { content: file }
        expect(response).to have_http_status(201)
      end
    end

    context 'guest with all permissions' do
      let!(:guest) { create :rspec_guest, set_permissions: [:document_create, :folder_add_document] }
      let!(:folder) { create :folder }
      it 'returns authorization error' do
        file = Rack::Test::UploadedFile.new(Rails.root.join('spec/fixtures/compressed.tracemonkey-pldi-09.pdf'))
        post "/rspec/folders/#{folder.id}/documents", headers: rspec_session(guest),
                                 params: { content: file }
        expect(response).to have_http_status(403)
      end
    end

    context 'admin without any permissions' do
      let!(:admin) { create :rspec_administrator }
      let!(:folder) { create :folder }
      it 'uploads a document to a folder' do
        file = Rack::Test::UploadedFile.new(Rails.root.join('spec/fixtures/compressed.tracemonkey-pldi-09.pdf'))
        post "/rspec/folders/#{folder.id}/documents", headers: rspec_session(admin),
                                 params: { content: file }
        expect(response).to have_http_status(201)
      end
    end

    context 'without folder permission' do
      let!(:folder) { create :folder }
      let!(:document_permission) { create :permission, code: :document_create, account_user: AccountUser.last }
      it 'returns authorization error' do
        file = Rack::Test::UploadedFile.new(Rails.root.join('spec/fixtures/compressed.tracemonkey-pldi-09.pdf'))
        post "/rspec/folders/#{folder.id}/documents", headers: rspec_session,
                                 params: { content: file }
        expect(response).to have_http_status(403)
      end
    end

    context 'without document permission' do
      let!(:folder) { create :folder }
      let!(:folder_permission) { create :permission, code: :folder_add_document, account_user: AccountUser.last }
      it 'returns authorization error' do
        file = Rack::Test::UploadedFile.new(Rails.root.join('spec/fixtures/compressed.tracemonkey-pldi-09.pdf'))
        post "/rspec/folders/#{folder.id}/documents", headers: rspec_session,
                                 params: { content: file }
        expect(response).to have_http_status(403)
      end
    end

    context 'without any permission' do
      let!(:folder) { create :folder }
      it 'returns authorization error' do
        file = Rack::Test::UploadedFile.new(Rails.root.join('spec/fixtures/compressed.tracemonkey-pldi-09.pdf'))
        post "/rspec/folders/#{folder.id}/documents", headers: rspec_session,
                                 params: { content: file }
        expect(response).to have_http_status(403)
      end
    end
  end

  describe 'GET /rspec/folders/1/documents' do
    context 'with permission' do
      let!(:document) { create :subdocument }
      let!(:document_permission) { create :permission, code: :document_index, account_user: AccountUser.last }
      let!(:folder_permission) { create :permission, code: :folder_documents, account_user: AccountUser.last }
      it 'returns folder documents' do
        get "/rspec/folders/#{document.folder.id}/documents", headers: rspec_session
        expect(response).to have_http_status(200)
      end
    end

    context 'admin without any permissions' do
      let!(:admin) { create :rspec_administrator }
      let!(:document) { create :subdocument }
      it 'returns folder documents' do
        get "/rspec/folders/#{document.folder.id}/documents", headers: rspec_session(admin)
        expect(response).to have_http_status(200)
      end
    end

    context 'without document permission' do
      let!(:document) { create :subdocument }
      let!(:folder_permission) { create :permission, code: :folder_documents, account_user: AccountUser.last }
      it 'returns authorization error' do
        get "/rspec/folders/#{document.folder.id}/documents", headers: rspec_session
        expect(response).to have_http_status(403)
      end
    end

    context 'without folder permission' do
      let!(:document) { create :subdocument }
      let!(:document_permission) { create :permission, code: :document_index, account_user: AccountUser.last }
      it 'returns authorization error' do
        get "/rspec/folders/#{document.folder.id}/documents", headers: rspec_session
        expect(response).to have_http_status(403)
      end
    end

    context 'without any permission' do
      let!(:document) { create :subdocument }
      it 'returns authorization error' do
        get "/rspec/folders/#{document.folder.id}/documents", headers: rspec_session
        expect(response).to have_http_status(403)
      end
    end
  end

  describe 'GET /rspec/folders/1/folders' do
    context 'with permission' do
      let!(:folder) { create :folder }
      let!(:permission) { create :permission, code: :folder_folders, account_user: AccountUser.last }
      it 'retrieves subfolders' do
        get "/rspec/folders/#{folder.id}/folders", headers: rspec_session
        expect(response).to have_http_status(200)
      end
    end

    context 'admin without permission' do
      let!(:admin) { create :rspec_administrator }
      let!(:folder) { create :folder }
      it 'retrieves subfolders' do
        get "/rspec/folders/#{folder.id}/folders", headers: rspec_session(admin)
        expect(response).to have_http_status(200)
      end
    end

    context 'without permission' do
      let!(:folder) { create :folder }
      it 'returns authorization error' do
        get "/rspec/folders/#{folder.id}/folders", headers: rspec_session
        expect(response).to have_http_status(403)
      end
    end
  end

  describe 'DELETE /rspec/folders/:folder' do
    context 'with permission' do
      let!(:folder) { create :folder }
      let!(:permission) { create :permission, code: :folder_destroy, account_user: AccountUser.last }
      it 'deletes folder' do
        delete "/rspec/folders/#{folder.id}", headers: rspec_session
        expect(response).to have_http_status(204)
      end
    end

    context 'guest with permission' do
      let!(:guest) { create :rspec_guest, set_permissions: [:folder_destroy] }
      let!(:folder) { create :folder }
      it 'returns authorization error' do
        delete "/rspec/folders/#{folder.id}", headers: rspec_session(guest)
        expect(response).to have_http_status(403)
      end
    end

    context 'admin without permission' do
      let!(:admin) { create :rspec_administrator }
      let!(:folder) { create :folder }
      it 'deletes folder' do
        delete "/rspec/folders/#{folder.id}", headers: rspec_session(admin)
        expect(response).to have_http_status(204)
      end
    end

    context 'without permission' do
      let!(:folder) { create :folder }
      it 'returns authorization error' do
        delete "/rspec/folders/#{folder.id}", headers: rspec_session
        expect(response).to have_http_status(403)
      end
    end
  end
end
