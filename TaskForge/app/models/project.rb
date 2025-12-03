class Project < ApplicationRecord
  belongs_to :organization
  has_many :tasks, dependent: :destroy

  validates :name, presence: true

  scope :for_organization, ->(org) { where(organization: org) }
end

