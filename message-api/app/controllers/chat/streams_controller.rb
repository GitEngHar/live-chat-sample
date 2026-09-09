module Chat
  class StreamsController < ApplicationController
    # GET /chat/streams/index?room_id=1
    def index
      room = Room.find_by(id: params[:room_id])
      return render json: { errors: ["room_id が不正です"] }, status: :unprocessable_entity unless room

      messages = room.messages.includes(:user).order(:created_at)
      render json: messages.map { |message| serialize(message) }, status: :ok
    end

    # POST /chat/streams/create
    # params: room_id, user_id, content
    def create
      room = Room.find_by(id: params[:room_id])
      user = User.find_by(id: params[:user_id])
      return render json: { errors: ["room_id または user_id が不正です"] }, status: :unprocessable_entity unless room && user

      message = room.messages.new(user: user, content: params[:content])

      if message.save
        ChatChannel.broadcast_to(room, serialize(message))
        render json: serialize(message), status: :created
      else
        render json: { errors: message.errors.full_messages }, status: :unprocessable_entity
      end
    end

    private

    def serialize(message)
      {
        id: message.id,
        room_id: message.room_id,
        user_id: message.user_id,
        sender: message.user.name,
        content: message.content,
        created_at: message.created_at.iso8601
      }
    end
  end
end
