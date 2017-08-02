class ApplicationController < ActionController::Base
  protect_from_forgery

  include Pundit
  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized
  after_action :verify_authorized, unless: :devise_controller?

  before_action :configure_permitted_parameters, if: :devise_controller?
  force_ssl if: -> { Rails.env.production? }, unless: :allow_insecure?

  before_action do
    @honeycomb_metadata = {}
    if current_user.try(:admin?)
      Rack::MiniProfiler.authorize_request
    end
  end

  rescue_from(ActionView::MissingTemplate) do |e|
    if request.format != :html
      head(:not_acceptable)
    else
      raise
    end
  end

  def after_sign_in_path_for(resource)
    params[:return_to] || super
  end

  def append_info_to_payload(payload)
    super

    metadata = @honeycomb_metadata
    if current_user
      metadata[:current_user_id] = current_user.id
      metadata[:current_user_email] = current_user.email
      metadata[:current_user_admin] = current_user.try(:admin?) ? true : false
    end
    metadata[:flash_error] = flash[:error] if flash[:error]
    metadata[:flash_notice] = flash[:notice] if flash[:notice]

    # Attach to ActiveSupport::Instrumentation payload for consumption by
    # subscribers
    payload[:metadata] = metadata
  end

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up) do |u|
      u.permit(policy(User).permitted_attributes + [region_ids: []])
    end
  end

  def allow_insecure?
    false
  end

  def user_not_authorized
    flash[:error] = "You are not authorized to perform this action."
    redirect_to(request.referer || root_path)
  end

  def with_timer(name)
    start = Time.now
    block_result = yield
    dur = (Time.now - start) * 1000 # in milliseconds
    @honeycomb_metadata["#{ name }_dur_ms"] = dur
    block_result
  end
end
