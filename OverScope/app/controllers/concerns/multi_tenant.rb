module MultiTenant
  extend ActiveSupport::Concern

  included do
    before_action :set_current_organization
    helper_method :current_organization
  end

  private

  def current_organization
    @current_organization ||= current_user&.current_organization
  end

  def set_current_organization
    @current_organization = current_organization
  end

  def require_organization
    redirect_to root_path, alert: "You must belong to an organization" unless current_organization
  end
end

