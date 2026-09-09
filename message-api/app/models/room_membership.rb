class RoomMembership < ApplicationRecord
  belongs_to :room, inverse_of: :room_memberships
  belongs_to :user, inverse_of: :room_memberships

  validates :user_id, uniqueness: { scope: :room_id }
end
