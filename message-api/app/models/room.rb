class Room < ApplicationRecord
  belongs_to :owner, class_name: "User", inverse_of: :owned_rooms

  has_many :room_memberships, dependent: :destroy
  has_many :members, through: :room_memberships, source: :user
  has_many :messages, dependent: :destroy, inverse_of: :room

  validates :name, presence: true
end
