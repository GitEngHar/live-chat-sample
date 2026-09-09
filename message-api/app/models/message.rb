class Message < ApplicationRecord
  belongs_to :room, inverse_of: :messages
  belongs_to :user, inverse_of: :messages

  validates :content, presence: true
end
