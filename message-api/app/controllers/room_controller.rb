class RoomController < ApplicationController
  # GET /room/index?user_id=1
  def index
    rooms = Room.all.includes(:room_memberships)
    joined_room_ids = params[:user_id].present? ? RoomMembership.where(user_id: params[:user_id]).pluck(:room_id) : []

    render json: rooms.map { |room| serialize(room, joined_room_ids) }, status: :ok
  end

  # POST /room/create
  def create
    owner = User.find_by(id: params[:user_id])
    return render json: { errors: ["user_id が不正です"] }, status: :unprocessable_entity unless owner

    room = Room.new(name: params[:name], owner: owner)

    if room.save
      join_room(room, owner)
      render json: serialize(room, [room.id]), status: :created
    else
      render json: { errors: room.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PUT /room/action
  # params: room_id, user_id, action_type ("join" または "leave")
  # NOTE: params[:action] は Rails がルーティング解決したコントローラーアクション名の予約キーであり、
  #       クライアント送信値では上書きできないため action_type という別名を使う。
  def action
    room = Room.find_by(id: params[:room_id])
    user = User.find_by(id: params[:user_id])
    return render json: { errors: ["room_id または user_id が不正です"] }, status: :unprocessable_entity unless room && user

    case params[:action_type]
    when "join"
      join_room(room, user)
    when "leave"
      room.room_memberships.find_by(user: user)&.destroy
    else
      return render json: { errors: ["action_type は join または leave を指定してください"] }, status: :unprocessable_entity
    end

    render json: serialize(room, room.room_memberships.where(user: user).exists? ? [room.id] : []), status: :ok
  end

  private

  # 1ユーザーは常に最大1ルームにのみ所属する。別ルームへの参加は旧ルームからの自動退出を伴う。
  def join_room(room, user)
    RoomMembership.where(user: user).where.not(room_id: room.id).destroy_all
    room.room_memberships.find_or_create_by!(user: user)
  end

  def serialize(room, joined_room_ids)
    {
      id: room.id,
      name: room.name,
      owner_id: room.owner_id,
      member_count: room.room_memberships.size,
      joined: joined_room_ids.include?(room.id)
    }
  end
end
