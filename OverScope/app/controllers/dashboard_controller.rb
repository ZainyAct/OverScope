class DashboardController < ApplicationController
  def index
    require_organization
    return unless current_organization

    @org_stats = fetch_org_stats
    @metrics = fetch_daily_metrics
  end

  private

  def fetch_org_stats
    ActiveRecord::Base.connection.execute(
      "SELECT * FROM org_30_day_stats WHERE organization_id = '#{current_organization.id}'"
    ).first
  end

  def fetch_daily_metrics
    current_organization.task_metrics_daily
      .where('date >= ?', 30.days.ago)
      .order(date: :asc)
  end
end

