require 'polydesk/auth_context'

# TODO: For all POST requests that contain resource objects, need to check
# type and return 409 if it doesn't match with the collection resource type.
class ApplicationController < ActionController::API
  before_action :forbid_client_generated_id, only: :create
  before_action :set_tenant
  after_action :clear_tenant

  if Rails.env.test?
    after_action :verify_authorized, unless: :devise_controller?
  end

  include DeviseTokenAuth::Concerns::SetUserByToken
  include Pundit
  include Polydesk

  rescue_from ActiveRecord::RecordNotFound, with: :not_found_exception
  rescue_from ActiveRecord::RecordInvalid, with: :invalid_exception
  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized
  rescue_from Polydesk::ApiExceptions::AccountIsDisabled, with: :invalid_exception
  rescue_from Polydesk::ApiExceptions::InvalidConfirmationToken, with: :invalid_confirmation_token_exception
  rescue_from Polydesk::ApiExceptions::NotVersionable, with: :invalid_exception
  rescue_from Polydesk::ApiExceptions::DocumentException::StorageLimitReached, with: :invalid_exception
  rescue_from Polydesk::ApiExceptions::FormSchemaViolated, with: :invalid_exception
  rescue_from Polydesk::ApiExceptions::UserException::NoAccountAccess, with: :forbidden_exception
  rescue_from Polydesk::ApiExceptions::ClientGeneratedIdsForbidden, with: :client_generated_ids_forbidden_exception

  def pundit_user
    Polydesk::AuthContext.new(current_user, current_account)
  end

  def current_account
    Account.find_by_identifier(params[:identifier])
  end

  # GET /
  def show
    render json: {}, status: :ok
  end

  def render_authenticate_error
    account = Account.new
    account.errors.add('user', 'must be logged in')
    render json: ErrorSerializer.new(account.errors).serialized_json, status: :unauthorized
  end

  protected

  def page_offset
    (params.dig(:page, :offset) || 0).to_i
  end

  def page_limit
    (params.dig(:page, :limit) || 25).to_i
  end

  def allowed_attributes(_policy)
    policy_restrictions(:attributes, _policy)
  end

  def allowed_relationships(_policy)
    policy_restrictions(:relationships, _policy)
  end

  def sanitize_payload(payload, record_klass)
    _policy = policy(record_klass)
    forbid_disallowed_attributes(payload, _policy)
    forbid_disallowed_relationships(payload, _policy)
    payload
  end

  def sanitize_request_payload(payload)
    forbid_client_generated_id(payload)
  end

  def policy_restrictions(type, _policy)
    # Only relevant when creating or updating.
    return [] if !['create', 'update'].include?(action_name)
    # Get the policy for this record
    fn = :"allowed_#{type}_for_#{action_name}"
    # No attributes allowed without a Policy allowing them
    return [] if _policy.nil? || !_policy.respond_to?(fn)
    # Retrieve allowed attributes (default to none allowed)
    _policy.send(fn) || []
  end

  def set_tenant
    Apartment::Tenant.switch!(params['identifier'])
  end

  def clear_tenant
    Apartment::Tenant.switch!
  end

  private

  def invalid_confirmation_token_exception(exception)
    render_exception_for exception.record, status_code: :not_found
  end

  def client_generated_ids_forbidden_exception(exception)
    errors = [
      {
        id: 'Client generated IDs',
        message: 'Client generated IDs are forbidden'
      }
    ]
    render json: { errors: errors }, status: :unprocessable_entity
  end

  def user_not_authorized(exception)
    current_user.errors.add('user', 'is not authorized to perform this action')
    render_exception_for current_user, status_code: :forbidden
  end

  def forbidden_exception(exception)
    render_exception_for exception.record, status_code: :forbidden
  end

  def invalid_exception(exception)
    render_exception_for exception.record, status_code: :unprocessable_entity
  end

  def not_found_exception(exception)
    model = exception.model.underscore
    record = exception.model.singularize.classify.constantize.new
    record.errors.add(model, 'does not exist')
    render_exception_for record, status_code: :not_found
  end

  def render_exception_for(record, status_code:)
    render json: ErrorSerializer.new(record.errors).serialized_json, status: status_code || :unprocessable_entity
  end

  # JSON:API allows clients to specify an ID when creating resources. This
  # is not supported, so return 403 Forbidden per the specification.
  def forbid_client_generated_id
    if !request.params.fetch(:data, {}).fetch(:id, nil).nil?
      raise Polydesk::ApiExceptions::ClientGeneratedIdsForbidden.new
    end
  end

  # Return 403 Forbidden if any restricted attributes or relationships are
  # created or modified.
  def forbid_disallowed_attributes(payload, record_klass)
    allowed = allowed_attributes(record_klass)
    attributes = payload.dig('data', 'attributes')
    return if !attributes.respond_to?(:keys) || attributes.keys.empty?
    restricted = payload['data']['attributes'].keys - allowed.map { |k| k.to_s }
    if restricted.any?
      raise Polydesk::ApiExceptions::ForbiddenAttributes.new
    end
  end

  def forbid_disallowed_relationships(payload, _policy)
    allowed = allowed_relationships(_policy)
    relationships = payload.dig('data', 'relationships')
    return if !relationships.respond_to?(:keys) || relationships.keys.empty?
    restricted = relationships.keys - allowed.map { |k| k.to_s }
    if restricted.any?
      raise Polydesk::ApiExceptions::ForbiddenRelationships.new
    end
  end
end
