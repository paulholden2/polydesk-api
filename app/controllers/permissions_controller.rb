class PermissionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_account
  before_action :set_user
  before_action :set_account_user

  # POST /:identifier/users/:id/permissions
  def create
    authorize Permission, :create?
    @permission = Permission.find_by_code(params[:code]) || Permission.create!(permission_params)
    render json: JSONAPI::Serializer.serialize(@permission), status: :created
  end

  def destroy
    authorize Permission, :destroy?
    @permission = Permission.find_by_code(params[:code])
    return if @permission.nil?
    @permission.destroy
  end

  # GET /:identifier/users/:id/permissions
  def index
    authorize Permission, :index?
    @permissions = Permission.where(account_user_id: @account_user.user_id).order('id')
    render json: JSONAPI::Serializer.serialize(@permission), status: :ok
  end

  private

  def set_account
    @account = Account.find_by_identifier!(params[:identifier])
  end

  def set_user
    @user = Account.find(params[:id])
  end

  def set_account_user
    @account_user = AccountUser.find_by!(account_id: @account.id,
                                         user_id: @user.id)
  end

  def permission_params
    p = params.permit(:code)
    p[:account_user_id] = @account_user.id
    return p
  end
end
