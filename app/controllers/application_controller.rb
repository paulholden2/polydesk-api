class ApplicationController < ActionController::API
  include DeviseTokenAuth::Concerns::SetUserByToken
  include Pundit

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  def pundit_user
    Polydesk::AuthContext.new(current_user, params[:identifier])
  end

  # GET /
  def show
    render json: {}, status: :ok
  end

  def current_page
    (params[:page] || PaginationGenerator::DEFAULT_PAGE).to_i
  end

  def per_page
    (params[:limit] || PaginationGenerator::DEFAULT_PER_PAGE).to_i
  end

  private
    def user_not_authorized
      @user = User.new
      @user.errors.add('user', 'is not authorized to perform this action')
      render json: ErrorSerializer.new(@user.errors).serialized_json, status: :forbidden
    end
end
