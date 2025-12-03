class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :memberships, dependent: :destroy
  has_many :organizations, through: :memberships
  has_many :task_events, foreign_key: :actor_user_id, dependent: :nullify

  validates :email, presence: true, uniqueness: true

  def admin_of?(organization)
    memberships.exists?(organization: organization, role: 'admin')
  end

  def member_of?(organization)
    memberships.exists?(organization: organization)
  end

  def current_organization
    organizations.first
  end
end

