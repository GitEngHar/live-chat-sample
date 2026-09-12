class NotificationsController < ApplicationController
  # POST /notifications/broadcast
  # params: user_ids ([1, 2, 3]), content
  # 対象ユーザーそれぞれの ChatChannel 個人向けstream (stream_for current_user) にのみ配信する。
  # 他のユーザーには一切届かない。
  def create
    user_ids = Array(params[:user_ids])
    return render json: { errors: ["user_ids が不正です"] }, status: :unprocessable_entity if user_ids.empty?

    users = User.where(id: user_ids)
    payload = { type: "balance_warning", content: params[:content] }
    users.find_each { |user| ChatChannel.broadcast_to(user, payload) }

    render json: { broadcasted_to: users.pluck(:id) }, status: :ok
  end
end
