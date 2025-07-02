#!/bin/bash

# 路径必须在你设置的项目根目录：/rl-swarm-0.5
cd ~/rl-swarm-0.5 || {
    echo "❌ 找不到目录 /rl-swarm-0.5"
    exit 1
}

echo "🔍 检查 3000 端口是否被占用..."
PORT_PID=$(lsof -i :3000 -t)

if [ -n "$PORT_PID" ]; then
    echo "⚠️  端口 3000 被进程 $PORT_PID 占用，尝试强制关闭..."
    kill -9 "$PORT_PID" && echo "✅ 已释放端口 3000"
else
    echo "✅ 端口 3000 空闲"
fi

echo "🧼 停止并清理已有容器（如果存在）..."
docker-compose down

echo "🔄 重新构建并启动 swarm-cpu 容器..."
docker-compose up swarm-cpu
