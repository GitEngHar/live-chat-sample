Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  #
  get "up" => "rails/health#show", as: :rails_health_check

  # NOTE: User/Room モデルと同名になる namespace(User::UserController等)は
  #       Zeitwerkのオートロードでモデルクラスと衝突するため、プレーンなパスで定義する。
  post "user/create", to: "user#create" # ユーザー登録
  get "user/get", to: "user#get" # ユーザー取得(ログイン確認)

  get "room/index", to: "room#index" # ルーム一覧取得
  post "room/create", to: "room#create" # ルーム作成
  put "room/action", to: "room#action" # ユーザーのルーム参加状態管理

  namespace :chat do
      post "streams/create", to: "streams#create" # メッセージチャットの投稿
      get "streams/index", to: "streams#index" # ルームのメッセージ履歴取得
  end
end
