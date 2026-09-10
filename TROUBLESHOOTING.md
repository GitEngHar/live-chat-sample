# Troubleshooting

AnyCable Pro構成のライブチャットをECS Fargateで実際に動かすまでの障害対応ログ。
次に似たような壊れ方をしたときにすぐ引けるよう、各項目に症状・原因・修正内容(ファイルパス付き)を残している。

## インフラ層 (ECS / ネットワーク)

### タスクが起動しない: イメージが見つからない
- **症状**: `CannotPullContainerError: ... message-api:latest: not found`(frontendも同様)
- **原因**: `infrastructure/ecr.tf` でECRリポジトリ自体は作られていたが、一度もイメージがpushされていなかった。
- **対処**: `docker build --platform linux/amd64 ... && docker push ...` を両方に実施。ECSタスク定義は`:latest`を参照しているので、pushして`aws ecs update-service --force-new-deployment`すれば反映される。

### anycable-go-pro: ghcr.ioから401
- **症状**: `CannotPullContainerError: ... failed to authorize ... 401 Unauthorized`(`ghcr.io/anycable/anycable-go-pro`)
- **原因**: Pro版イメージはghcr.io上の非公開パッケージで、匿名pullが拒否される。
- **対処**: `infrastructure/secrets.tf`(`ghcr_credentials`シークレット)+ `infrastructure/ecs.tf`(anycable-goコンテナに`repositoryCredentials`を設定)。AnyCable Proライセンスに紐づくGitHub PAT(`read:packages`)が必要で、`TF_VAR_ghcr_username` / `TF_VAR_ghcr_token`として渡す。

### message-api: port 80で`bind: permission denied`
- **症状**: コンテナが即座に落ち、ログに`listen tcp :80: bind: permission denied`
- **原因**: `message-api/Dockerfile`の最終ステージが非rootユーザー(`USER 1000:1000`)で実行される。1024番未満の特権ポートのbindにはrootまたは`CAP_NET_BIND_SERVICE`が必要 — ローカルのDocker環境(`net.ipv4.ip_unprivileged_port_start`が緩い設定)ではたまたま動いていたが、Fargateでは通らない。
- **対処**: Thrusterの待受ポートを非特権ポートにする`HTTP_PORT=3001`環境変数を追加(`infrastructure/ecs.tf`)、target group/SG/ALBリスナールールも3001に変更(`infrastructure/network.tf`)。

### message-api: port 80修正直後に`Address already in use`
- **症状**: `Errno::EADDRINUSE ... bind(2) for "0.0.0.0" port 3000`
- **原因**: Thruster用に`HTTP_PORT=3000`を設定したが、Puma/Rails自体もデフォルトで3000番を使うため、コンテナ内で2つのプロセスが同じポートを取り合っていた。
- **対処**: Pumaが使っていないポートに変更 — `HTTP_PORT=3001`とし、Pumaはデフォルトの3000番のまま(Thrusterが内部でそこにプロキシする)。

### `/api/*`パスルーティングが404
- **症状**: `https://<domain>/api/up` → target groupはタスクをhealthyと判定しているのに404
- **原因**: `message-api/config/routes.rb`には`/api`プレフィックスが一切無い(`/user/create`、`/room/index`など)。ALBの`forward`アクションはパスの書き換えができないため、`/api/up`はそのまま`/api/up`として転送され、存在しないパスになっていた。
- **対処**: パスベースではなくホストベースのルーティングに変更 — 同じALBに`api.<domain>`専用サブドメインを追加(`infrastructure/dns.tf`、`network.tf`の`aws_lb_listener_rule`を`path_pattern`から`host_header`へ)。ACM証明書のSANにapex + `api.` + `cable.`を含める必要があり、証明書自体の再発行・再検証が発生した(発行済み証明書に後からSANを追加することはできないため)。

### Target Groupの置き換えで`ResourceInUse`
- **症状**: `port`を変更するたびに`terraform apply`が`Target group '...' is currently in use by a listener or a rule`でエラー
- **原因**: Target Groupの`name`が固定だった。AWSは同名のTarget Groupを2つ同時に存在させられないため、Terraformはcreate-before-destroyができず先に削除しようとするが、リスナー/ルールがまだ参照中なので拒否される。
- **対処**: 3つのTarget Groupすべてを`name_prefix`(最大6文字)+ `lifecycle { create_before_destroy = true }`に変更(`infrastructure/network.tf`)。これでポート変更時は新規作成→リスナー/サービスの参照切替→旧TG削除、という安全な順序になる。

### rpc-server: `Could not find table 'users'`
- **症状**: anycable-goでのWebSocket認証が全て`Application error: Could not find table 'users'`で失敗
- **原因**: `message-api`はSQLiteを使用(`config/database.yml`、`storage/*.sqlite3`)。`bin/docker-entrypoint`はコンテナのコマンドが厳密に`./bin/rails server`のときだけ`db:prepare`を実行する仕様で、rpc-serverのコマンドは`bundle exec anycable`のためDBが一切マイグレーションされない。さらに、Fargateでは各ECSタスクが独立した一時ファイルシステムを持つため(docker-composeの`message_api_storage`のような共有ボリュームが無い)、たとえ両方マイグレーションしてもmessage-apiとrpc-serverはそれぞれ**別々の**SQLiteファイルを持つことになる。
- **最初の対処**: `/rails/storage`にEFS共有ボリュームをマウント。その後`SQLite3::CantOpenException: unable to open database file`という別エラーに遭遇 — EFSのルートはroot所有で、コンテナはuid 1000で動くため書き込めなかった。`aws_efs_access_point`(`creation_info`でowner_uid/gidを1000に指定)で対処。
- **最終的な対処**: EFSは撤去し、primaryデータベースをRDS PostgreSQLに移行(`infrastructure/rds.tf`)。SQLite-over-NFSのロック/権限問題を根本から回避できる。`cache`/`queue`/`cable`のサブDBはローカルの一時SQLiteのままにした — 再起動で消えても実害はないため(`message-api/config/database.yml`のコメント参照)。`message-api/Gemfile`に`gem "pg"`を追加し、`database.yml`の`production.primary`を`url: <%= ENV.fetch("DATABASE_URL") %>`に変更。

### message-api: 新タスクがデプロイ中に何度も落とされる
- **症状**: `force-new-deployment`すると新タスクが一瞬`running`になるがすぐ止まり、旧タスクが残ったままデプロイが収束しない
- **原因**: ECSサービスに`health_check_grace_period_seconds`が未設定だった。Rails起動 + RDSへの初回(コールド)接続 + `db:prepare`で30〜40秒かかるが、その間にALBヘルスチェックが失敗と判定してしまい、ECSが「unhealthy」とみなして新タスクを巻き戻していた。
- **対処**: `message-api`の`aws_ecs_service`に`health_check_grace_period_seconds = 90`を設定(`infrastructure/ecs.tf`)。

### Secrets Manager: `ResourceNotFoundException ... AWSCURRENT`
- **症状**: シークレット作成直後に`unable to retrieve secret from asm: ... can't find the specified secret value for staging label: AWSCURRENT`
- **原因**: `aws_secretsmanager_secret`の作成と、そのバージョンが`AWSCURRENT`になるまでの間に結果整合性のラグがあり、同じapply内で起動したタスクがそれより先行してしまうことがある。
- **対処**: 構造的な対処は不要 — 少し待ってから再デプロイすれば解消する(1分程度でシークレットは完全に伝播する)。シークレットを触るapplyの直後にサービスデプロイを続ける場合は注意。

## アプリケーション層 (message-api / anycable-go-pro)

### anycable-goがクラッシュループ: ValkeyのURLパースエラー
- **症状**: `couldn't configure pub/sub, cause: parse "rediss://:xxx!": invalid port ":xxx!" after host`
- **原因**: ElastiCacheのAUTHトークン(`random_password.valkey_auth`)に`#`を許容していたが、これはURIのフラグメント区切り文字であるため、`rediss://`URLを組み立てる際に`#`以降が黙って切り捨てられ、ホスト/ポート部分が壊れていた。
- **対処**: シークレット文字列を組み立てる際にトークンを`urlencode()`で囲む(`infrastructure/valkey.tf`の`aws_secretsmanager_secret_version.valkey_url`)。原則として、ランダム生成した秘密情報を文字集合を絞っただけでURLに直接埋め込むのは避け、必ず`urlencode()`を通すこと。

### WebSocketは繋がるが全セッションが`unauthorized`
- **症状**: 生のWS接続自体は開通するが、`ApplicationCable::Connection#find_verified_user`が常に拒否し、サーバーログに`failed to authenticate`
- **原因**: `message-api/app/controllers/user_controller.rb`の`sign_in`が`cookies.encrypted[:user_id]`を`domain:`指定なしでセットしていたため、ログインを処理したサブドメイン(`api.<domain>`)専用のホスト固有Cookieになっていた。WebSocketの接続先は別のサブドメイン(`cable.<domain>`)なので、ブラウザはホスト固有Cookieをそちらには送らない。
- **対処**: Cookieに`domain: :all`を指定(`message-api/app/controllers/user_controller.rb`) — サイト内の全サブドメイン(`api.`、`cable.`、apex)で共有されるようになる。

### REST経由で投稿したメッセージが接続中のWSクライアントに届かない
- **症状**: `ChatChannel.broadcast_to`はエラー無く実行され、メッセージはDBに保存されるが、購読者は誰も受信しない
- **原因**: `ANYCABLE_HTTP_BROADCAST_URL`が`http://anycable-go:8090/_broadcast`を指していたが、anycable-go自身の起動ログには`Accept broadcast requests at http://0.0.0.0:8080/_broadcast`とあり、broadcastはWebSocketと同じ8080番を共有していた — 8090番は誰もlistenしていなかった。(8090は元のdocker-compose.yamlからそのまま持ってきた値で、このAnyCable-go-proバージョンが実際に別ポートを使うかどうかを確認していなかった。実際は使わない。)
- **対処**: `ANYCABLE_HTTP_BROADCAST_URL`をポート8080に修正(`infrastructure/ecs.tf`)。使われていなかった8090番のポートマッピング/Service Connectエイリアス/セキュリティグループルールも削除(`network.tf`)。

### 参加人数(presence)が常に0、anycable-goログにRedisエラー
- **症状**: `failed to process presence ... failed to store presence in Redis, cause: Unknown command called from script ... on @user_script:21`
- **原因**: AnyCableのRedisバックエンドpresence機能は**Redis 7.4以上またはValkey 9.0以上**が必要(ハッシュフィールドTTL用のLuaコマンドがこのバージョンから導入されたため) — https://docs.anycable.io/anycable-go/presence 。使っていたElastiCache Valkeyは8.0だった。
- **対処**: `valkey_engine_version`を`9.1`に変更(`infrastructure/variables.tf`)、`apply_immediately = true`(`infrastructure/valkey.tf`)。in-placeのエンジンアップグレードで約19分かかったが、通常のフェイルオーバー程度のブリップ以外のダウンタイムは無し。

## フロントエンド層

### ページを再読み込みしないとリアルタイム更新が効かない
- **症状**: 新規ログインしてルームに初めて入っても(再読み込みなし)チャットがリアルタイム更新されず、参加人数も0のまま。ルームに入った状態でページを再読み込みすると動き出す。
- **原因**: `frontend/src/cable.ts`が**モジュール読み込み時**に`createCable()`を呼んでいた(`const cable = createCable(...)`)。`cable.ts`はアプリのエントリチェーン(`main → App → MainScreen → ChatScreen → cable`)から静的importされているため、このコードはページが開かれるたびに実行される — ログイン前、つまり認証Cookieがまだ無い状態でも実行されてしまう。この時点での接続は`{"type":"disconnect","reason":"unauthorized","reconnect":false}`で拒否され、`reconnect: false`の指定により二度と再接続を試みない。以降の`subscribeToRoom()`呼び出しは全てこの死んだ接続の上で行われる。ページを再読み込みするとモジュールが新しく評価され、その時点では既に`localStorage`とCookieが揃っているため、最初から正しく接続できる。
- **対処**: `cable`シングルトンの生成をモジュールスコープではなく`subscribeToRoom()`内での初回利用時まで遅延させる(`frontend/src/cable.ts`) — これにより最初の接続試行が必ずログイン後になる。

## 全般的な教訓
- ローカルのdocker-composeで動くことは、同じ設定がFargateでも動く保証にはならない — 特権ポート、共有ボリューム、非rootユーザーはそれぞれ挙動が変わる。
- サブドメインをまたぐ設定(Cookie、CORS、broadcast URL)は、ドメイン/ポートを都度明示的に確認すること — 単一ホストのdev環境から持ち越した値をそのまま信用しない。
- さらに深いレイヤーをデバッグする前に、依存ライブラリのバージョン要件と実際にデプロイされているバージョンを照合する(Valkey/presenceの件は、これを先に確認していれば余計な時間を使わずに済んだ)。
- 「再読み込みすれば動くが初回は動かない」は、ほぼ確実に初期化順序/認証タイミングのバグ — モジュール評価時点で実行されるコードと、関連する非同期状態(ログイン、Cookie)が揃うタイミングの前後関係を疑うこと。
