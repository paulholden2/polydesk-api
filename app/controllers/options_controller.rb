class OptionsController < ApplicationController
  # GET /:identifier/options
  def index
    Apartment::Tenant.switch(params['identifier']) do
      @options = Option.all.order('id').page(current_page).per(per_page)
      options = PaginationGenerator.new(request: request, paginated: @options).generate

      render json: OptionSerializer.new(@options, options).serialized_json, status: :ok
    end
  end

  # GET /:identifier/options/:id
  def show
    Apartment::Tenant.switch(params['identifier']) do
      set_option
      render json: OptionSerializer.new(@options).serialized_json, status: :ok
    end
  end

  # POST /:identifier/options
  def create
    Apartment::Tenant.switch(params['identifier']) do
      @option = Option.find_by_name params['name']
      if @option
        @option.update(option_params)
      else
        @option = Option.new(option_params)
      end
      @option.save!
      render json: OptionSerializer.new(@option).serialized_json, status: :created
    end
  end

  # PATCH/PUT /:identifier/options/:id
  def update
    Apartment::Tenant.switch(params['identifier']) do
      set_option
      if @option.update(option_params)
        render json: OptionSerializer.new(@option).serialized_json, status: :ok
      else
        render json: @option.errors, status: :unprocessable_entity
      end
    end
  end

  # DELETE /:identifier/options/:id
  def destroy
    Apartment::Tenant.switch(params['identifier']) do
      set_option
      @option.destroy
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_option
      @option = Option.find(params[:id])
    end

    # Only allow a trusted parameter "white list" through.
    def option_params
      params.permit(:name, :value)
    end
end