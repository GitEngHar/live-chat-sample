class User < ApplicationRecord
  has_many :room_memberships, dependent: :destroy
  has_many :rooms, through: :room_memberships
  has_many :owned_rooms, class_name: "Room", foreign_key: :owner_id, dependent: :destroy, inverse_of: :owner
  has_many :messages, dependent: :destroy, inverse_of: :user

  validates :name, presence: true, uniqueness: true
  validates :password, presence: true
end
