# frozen_string_literal: true
module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user
    def connect
      Rails.logger.info "[AnyCable RPC] Connection#connect called"

      self.current_user = find_verified_user
    end

    def find_verified_user
      Rails.logger.info "[AnyCable RPC] find_verified_user called"
      verified_user = User.find_by(id: cookies.encrypted[:user_id])
      if verified_user.present?
        verified_user
      else
        reject_unauthorized_connection
      end
    end
  end
end
