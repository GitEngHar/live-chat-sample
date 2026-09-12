1. タスクを起動

```bash
aws ecs run-task --profile cinema-ai --region ap-northeast-1 \
   --cluster live-chat-cluster \
   --task-definition valkey-debug \
   --launch-type FARGATE \
   --enable-execute-command \
   --network-configuration "awsvpcConfiguration={subnets=[subnet-07302dbde7ec0b8c0],securityGroups=[sg-0eb21f6b322ec6c6d],assignPublicIp=ENABLED}" \
   --query 'tasks[0].taskArn' --output text
```


2. RUNNINGになるまで待つ(30秒〜1分程度)

```bash
aws ecs describe-tasks --profile cinema-ai --region ap-northeast-1 \
--cluster live-chat-cluster --tasks <上で出たtaskArn> \
--query 'tasks[0].lastStatus' --output text

```

3. シェルに入る

```bash
aws ecs execute-command --profile cinema-ai --region ap-northeast-1 \
   --cluster live-chat-cluster --task <taskArn> \
   --container redis-debug --interactive --command "/bin/sh"

```

4. シェル内でAUTHトークンを確認してredis-cliで接続(トークンはローカルの別ターミナルで先に取得しておくと楽です):
# 別ターミナルでトークンだけ抜き出す例

`live-chat/dev/valkey-url` の secret値からTOKENを抜き出す

# → rediss://:<urlencodeされたトークン>@master.live-chat-valkey.nb4kz9.apne1.cache.amazonaws.com:6379

```bash
export REDISCLI_AUTH='bZtwYqef%21%23%3C1tlQ73ZX3UsEK%24OApq4r0'
redis-cli -h master.live-chat-valkey.nb4kz9.apne1.cache.amazonaws.com -p 6379 --tls

```
XRANGE '$ac:s::chat:Z2lkOi8vbWVzc2FnZS1hcGkvUm9vbS8y' - +

5. 終わったら片付け
```bash
aws ecs stop-task --profile cinema-ai --region ap-northeast-1 --cluster live-chat-cluster --task arn:aws:ecs:ap-northeast-1:363471485358:task/live-chat-cluster/89ab650ac5b2474592195f4a8f1ddc6a
aws ecs deregister-task-definition --profile cinema-ai --region ap-northeast-1 --task-definition valkey-debug:1
aws iam delete-role-policy --profile cinema-ai --role-name valkey-debug-task-role --policy-name ecs-exec
aws iam delete-role --profile cinema-ai --role-name valkey-debug-task-role 
```
   
このシステム一旦d