```bash
cd message-api
aws ecr get-login-password --profile cinema-ai --region ap-northeast-1 \
  | docker login --username AWS --password-stdin 363471485358.dkr.ecr.ap-northeast-1.amazonaws.com
docker build --platform linux/amd64 \
-t 363471485358.dkr.ecr.ap-northeast-1.amazonaws.com/live-chat/message-api:latest .
docker push 363471485358.dkr.ecr.ap-northeast-1.amazonaws.com/live-chat/message-api:latest
aws ecs update-service --profile cinema-ai --region ap-northeast-1 --cluster live-chat-cluster --service message-api --force-new-deployment
aws ecs update-service --profile cinema-ai --region ap-northeast-1 --cluster live-chat-cluster --service rpc-server --force-new-deployment
```
frontend変更時:
```bash

cd frontend
docker build --platform linux/amd64 \
    --build-arg VITE_API_BASE_URL=https://api.gitenghar-live-chat.com \
    --build-arg VITE_CABLE_URL=wss://cable.gitenghar-live-chat.com:30001/cable \
    -t 363471485358.dkr.ecr.ap-northeast-1.amazonaws.com/live-chat/frontend:latest .
docker push 363471485358.dkr.ecr.ap-northeast-1.amazonaws.com/live-chat/frontend:latest
aws ecs update-service --profile cinema-ai --region ap-northeast-1 --cluster live-chat-cluster --service frontend --force-new-deployment
```