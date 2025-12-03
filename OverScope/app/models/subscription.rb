class Subscription < ApplicationRecord
  belongs_to :organization

  validates :status, inclusion: { in: %w[active past_due canceled incomplete trialing] }

  scope :active, -> { where(status: 'active') }
end

