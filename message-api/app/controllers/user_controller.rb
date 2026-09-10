class UserController < ApplicationController
  # POST /user/create
  def create
    user = User.new(name: params[:name], password: params[:password])

    if user.save
      sign_in(user)
      render json: serialize(user), status: :created
    else
      render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # GET /user/get
  # name/password が一致するユーザーを返すログイン確認用エンドポイント
  def get
    user = User.find_by(name: params[:name], password: params[:password])

    if user
      sign_in(user)
      render json: serialize(user), status: :ok
    else
      render json: { errors: ["name または password が一致しません"] }, status: :unauthorized
    end
  end

  private

  # AnyCable の Connection#find_verified_user から参照するため、
  # ユーザーIDを暗号化Cookieに保存する。
  # frontend (apex), message-api (api.*), anycable-go (cable.*) がサブドメイン違いで
  # 動いているため、domain: :all で全サブドメイン共有Cookieにする
  # (指定しないとホスト固有Cookieになり、cable.* への WebSocket 接続時に送られない)。
  def sign_in(user)
    cookies.encrypted[:user_id] = { value: user.id, httponly: true, same_site: :lax, domain: :all }
  end

  def serialize(user)
    { id: user.id, name: user.name }
  end
end
