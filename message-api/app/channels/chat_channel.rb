# frozen_string_literal: true
class ChatChannel < ApplicationCable::Channel
  # メッセージの送信はWebSocket(perform_action)を経由せず、Chat::StreamsController#create
  # からHTTP経由でDBに保存した後にChatChannel.broadcast_toで配信する。
  # このチャンネルは配信の受信専用(subscribeのみ)。
  def subscribed
    room = Room.find_by(id: params[:room_id])
    reject unless room

    stream_for room
  end

  def unsubscribed
  end
end
