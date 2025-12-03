class TaskEvent < ApplicationRecord
  belongs_to :task
  belongs_to :actor_user, class_name: 'User', optional: true

  validates :event_type, presence: true,
            inclusion: { in: %w[created started completed reassigned] }
end

