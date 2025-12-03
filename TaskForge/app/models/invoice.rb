class Invoice < ApplicationRecord
  belongs_to :organization

  validates :status, inclusion: { in: %w[paid open void uncollectible draft] }
  validates :currency, presence: true

  def amount_dollars
    amount_cents.to_f / 100.0
  end
end

