class BillingController < ApplicationController
  before_action :require_organization

  def index
    @organization = current_organization
    # In a real app, you'd fetch subscription info from Stripe
    # For now, we'll show a placeholder
    @subscription = {
      plan: 'Pro',
      status: 'active',
      current_period_end: 30.days.from_now
    }
  end
end

