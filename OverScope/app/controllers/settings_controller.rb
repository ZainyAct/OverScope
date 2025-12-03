class SettingsController < ApplicationController
  before_action :require_organization

  def index
    @organization = current_organization
  end
end

