class Membership < ApplicationRecord
  belongs_to :user
  belongs_to :organization

  validates :role, inclusion: { in: %w[admin member] }
  validates :user_id, uniqueness: { scope: :organization_id }
end

