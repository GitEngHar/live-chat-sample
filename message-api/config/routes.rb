Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  #
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :user do # 簡単なユーザー管理基盤
    post "create", to: "user#create" # ユーザー登録
    get "get", to: "user#get" # ユーザー取得
  end

  namespace :room do
    post "create", to: "room#create" # メッセージチャットの投稿
    put "action", to: "room#action" # ユーザーのルーム参加状態管理
  end

  namespace :chat do
      post "streams/create", to: "streams#create" # メッセージチャットの投稿
  end
end
