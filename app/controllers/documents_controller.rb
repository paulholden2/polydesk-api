require 'json'

class DocumentsController < ApplicationController
  # User must be authenticated before they can interact with documents
  before_action :authenticate_user!

  def new
  end

  # POST /:identifier/documents
  def create
    Apartment::Tenant.switch(params[:identifier]) do
      @document = Document.new(document_params)
      authorize @document
      @document.save!
      render json: DocumentSerializer.new(@document).serialized_json, status: :created
    end
  end

  # PATCH/PUT /:identifier/documents/:id
  def update
    Apartment::Tenant.switch(params[:identifier]) do
      @document = Document.find(params[:id])
      @document.update(document_params)
      render json: DocumentSerializer.new(@document).serialized_json, status: :ok
    end
  end

  # POST /:identifier/documents/:id
  def show
    Apartment::Tenant.switch(params[:identifier]) do
      authorize Document, :show?
      @document = Document.find(params[:id])
      render json: DocumentSerializer.new(@document).serialized_json, status: :ok
    end
  end

  # GET /:identifier/documents
  def index
    Apartment::Tenant.switch(params[:identifier]) do
      authorize Document, :index?

      if params.key?(:root) && params[:root] == 'true' then
        @documents = Document.left_outer_joins(:folder)
                             .where(folders: { id: nil })
                             .references(:folders)
      else
        @documents = Document.all
      end

      @documents = @documents.order('id').page(current_page).per(per_page)
      options = PaginationGenerator.new(request: request, paginated: @documents).generate

      render json: DocumentSerializer.new(@documents, options).serialized_json, status: :ok
    end
  end

  # GET /:identifier/documents/:id/folder
  def folder
    Apartment::Tenant.switch(params[:identifier]) do
      authorize Document, :show?
      # authorize Folder, :show?

      @document = Document.find(params[:id])
      folder_json = FolderSerializer.new(@document.folder).serialized_json

      if @document.folder.nil?
        folder_json = { data: [] }
      end

      render json: folder_json, status: :ok
    end
  end

  # GET /:identifier/documents/:id/versions
  def versions
    Apartment::Tenant.switch(params[:identifier]) do
      authorize Document, :index?
      @document = Document.find(params[:id])
      # TODO: VersionSerializer
      render json: @document.versions, status: :ok
    end
  end

  # PUT /:identifier/documents/:id/versions/:version
  def reify
    Apartment::Tenant.switch(params[:identifier]) do
      authorize Document, :index?
      @document = Document.find(params[:id])
      @document = @document.versions.find(params[:version]).reify
      @document.save
      render json: DocumentSerializer.new(@document).serialized_json, status: :ok
    end
  end

  private
    def document_params
      params.permit(:content, :name)
    end
end
