require 'rails_helper'

RSpec.describe 'Prefabs', type: :request do
  let(:schema) {
    {
      type: 'object',
      properties: {
        field: {
          type: 'string'
        }
      }
    }
  }
  let!(:blueprint) { create :blueprint, schema: schema,
                                        namespace: 'fields',
                                        name: 'Fields Blueprint' }
  let(:view) {
    {
      stub: true
    }
  }
  let(:data) {
    {
      field: 'A String'
    }
  }
  let(:attributes) {
    {
      namespace: 'fields',
      schema: schema,
      view: view,
      data: data
    }
  }
  let(:relationships) {
    {
      blueprint: {
        data: {
          id: blueprint.id.to_s,
          type: 'blueprints'
        }
      }
    }
  }
  let(:params) {
    {
      data: {
        type: 'prefabs',
        attributes: attributes,
        relationships: relationships
      }
    }
  }
  let(:prefab) { create :prefab }

  describe 'GET /rspec/prefabs' do
    it 'lists all prefabs' do
      get '/rspec/prefabs', headers: rspec_session
      expect(response).to have_http_status(200)
    end
  end

  describe 'GET /rspec/prefabs/:id' do
    let(:prefab) { create :prefab }
    it 'shows prefab' do
      get "/rspec/prefabs/#{prefab.id}", headers: rspec_session
      expect(response).to have_http_status(200)
    end
  end

  describe 'POST /rspec/prefabs' do
    it 'creates new prefab' do
      post '/rspec/prefabs', headers: rspec_session,
                             params: params.to_json
      # puts response.inspect
      expect(response).to have_http_status(201)
    end
  end
end
