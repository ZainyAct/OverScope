class Task < ApplicationRecord
  belongs_to :project
  has_many :task_events, dependent: :destroy

  validates :title, presence: true
  validates :status, inclusion: { in: %w[open in_progress completed] }
  validates :priority, inclusion: { in: 1..5 }
  validates :complexity, inclusion: { in: 1..5 }, allow_nil: true
  validates :estimate_hours, numericality: { greater_than: 0 }, allow_nil: true

  scope :for_organization, ->(org) { joins(:project).where(projects: { organization_id: org.id }) }
  scope :open_or_in_progress, -> { where(status: %w[open in_progress]) }

  before_create :auto_estimate_if_needed
  after_update :track_estimation_accuracy_on_completion, if: :saved_change_to_status?

  def completed?
    status == 'completed'
  end

  def lead_time_hours
    return nil unless completed?

    completed_event = task_events.where(event_type: 'completed').order(created_at: :asc).first
    return nil unless completed_event

    (completed_event.created_at - created_at) / 3600.0
  end

  def actual_hours
    return nil unless completed?
    lead_time_hours
  end

  private

  def auto_estimate_if_needed
    return if estimate_hours.present?
    
    # Auto-estimate using Scala service
    begin
      client = ScalaTaskEngineClient.new
      result = client.estimate_task(self, user_id: nil)
      self.estimate_hours = result['estimateHours'] || 8
      self.complexity ||= 3
    rescue => e
      Rails.logger.error "Error auto-estimating task: #{e.message}"
      # Fallback to complexity-based default
      self.estimate_hours ||= complexity_based_default
      self.complexity ||= 3
    end
  end

  def complexity_based_default
    case complexity || 3
    when 1 then 2
    when 2 then 4
    when 3 then 8
    when 4 then 16
    when 5 then 32
    else 8
    end
  end

  def track_estimation_accuracy_on_completion
    return unless status == 'completed' && estimate_hours.present?
    return unless previous_changes['status']&.first != 'completed'

    # Get actual hours from lead time
    actual = lead_time_hours
    return unless actual && actual > 0

    # Get user who completed it
    completed_event = task_events.where(event_type: 'completed').order(created_at: :desc).first
    user_id = completed_event&.actor_user_id

    # Track accuracy via Scala service
    begin
      client = ScalaTaskEngineClient.new
      client.track_estimation_accuracy(id, estimate_hours, actual, user_id: user_id)
    rescue => e
      Rails.logger.error "Error tracking estimation accuracy: #{e.message}"
    end
  end
end

