#!/bin/bash

set -e

while true; do
    echo "[swarm_entrypoint] 启动 RL Swarm 主脚本..."
    bash /home/gensyn/rl_swarm/run_rl_swarm.sh
    echo "[swarm_entrypoint] 主脚本异常退出，5秒后自动重启..."
    sleep 5
done 