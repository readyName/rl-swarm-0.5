#!/bin/bash

set -euo pipefail

# 配置参数
RESTART_DELAY=30
CHECK_INTERVAL=10
PID_FILE="$PWD/training.pid"


# 颜色输出
GREEN="\033[32m"
BLUE="\033[34m"
RED="\033[31m"
YELLOW="\033[33m"
RESET="\033[0m"

# 重要信息日志（仅显示在终端）
log_important() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

echo_green() {
    echo -e "${GREEN}$1${RESET}"
}

echo_blue() {
    echo -e "${BLUE}$1${RESET}"
}

echo_red() {
    echo -e "${RED}$1${RESET}"
    log_important "$1"
}

echo_yellow() {
    echo -e "${YELLOW}$1${RESET}"
    log_important "$1"
}

# 清理函数
cleanup() {
    echo_yellow "🛑 正在停止监控..."

    if [ -f "$PID_FILE" ]; then
        local pid
        pid=$(cat "$PID_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            echo_yellow "终止训练进程 PID: $pid"
            kill -TERM "$pid" 2>/dev/null || true
            sleep 5
            if ps -p "$pid" > /dev/null 2>&1; then
                kill -KILL "$pid" 2>/dev/null || true
            fi
        fi
        rm -f "$PID_FILE"
    fi

    pkill -f "swarm_launcher.py" 2>/dev/null || true
    pkill -f "run_rl_swarm.sh" 2>/dev/null || true
    pkill -f "yarn start" 2>/dev/null || true

    echo_green "✅ 已停止"
    exit 0
}

# 检查进程是否运行
is_process_running() {
    if [ -f "$PID_FILE" ]; then
        local pid
        pid=$(cat "$PID_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            return 0
        fi
    fi

    if pgrep -f "swarm_launcher.py" > /dev/null 2>&1; then
        return 0
    fi

    return 1
}

# 启动训练进程
start_training() {
    echo_blue "🚀 启动 Mac M4 RL Swarm 训练..."

    export PYTORCH_MPS_HIGH_WATERMARK_RATIO=0.0
    export OMP_NUM_THREADS=8
    export MKL_NUM_THREADS=8
    export PYTORCH_ENABLE_MPS_FALLBACK=1
    export CPU_ONLY=1
    export HF_HUB_DOWNLOAD_TIMEOUT=300
    export HF_DATASETS_CACHE="$HOME/.cache/huggingface/datasets"
    export HF_MODELS_CACHE="$HOME/.cache/huggingface/transformers"

    export CONNECT_TO_TESTNET=true
    export SWARM_CONTRACT="0xFaD7C5e93f28257429569B854151A1B8DCD404c2"
    export HUGGINGFACE_ACCESS_TOKEN="None"
    export HF_TOKEN=""

    mkdir -p "$HF_DATASETS_CACHE" "$HF_MODELS_CACHE"

    if [ -f ".venv/bin/activate" ]; then
        source .venv/bin/activate
    else
        echo_red "❌ 虚拟环境不存在，请先运行部署脚本"
        return 1
    fi

    echo_blue "📝 使用预设参数启动训练"

    # 直接在终端运行 run_rl_swarm.sh，输出到当前终端
    {
        echo "$DEFAULT_MODEL_NAME"
    } | ./run_rl_swarm.sh &

    local pid=$!
    echo "$pid" > "$PID_FILE"
    echo_green "✅ 训练进程已启动，PID: $pid"

    sleep 15
    if ! ps -p "$pid" > /dev/null 2>&1; then
        echo_red "❌ 训练进程启动失败"
        rm -f "$PID_FILE"
        return 1
    fi

    return 0
}

# 信号处理
trap cleanup SIGINT SIGTERM

# 主监控循环
main() {
    local restart_count=0

    echo_green "🎯 Mac M4 RL Swarm 启动"
    echo_blue "⏱️  检查间隔: ${CHECK_INTERVAL}秒"
    echo_blue "⏰ 重启延迟: ${RESTART_DELAY}秒"
    echo ""

    if ! start_training; then
        echo_red "❌ 初始启动失败"
        exit 1
    fi

    while true; do
        sleep "$CHECK_INTERVAL"

        if ! is_process_running; then
            echo_yellow "⚠️  检测到训练进程已结束"
            restart_count=$((restart_count + 1))
            echo_yellow "🔄 准备第 $restart_count 次重启"
            echo_yellow "⏰ 等待 $RESTART_DELAY 秒后重启..."
            sleep "$RESTART_DELAY"

            if start_training; then
                echo_green "✅ 第 $restart_count 次重启成功"
            else
                echo_red "❌ 第 $restart_count 次重启失败，将继续尝试"
            fi
        fi
    done

    cleanup
}

# 启动前检查
if [ ! -f "run_rl_swarm.sh" ]; then
    echo_red "❌ 错误: 请在 rl-swarm 项目根目录下运行此脚本"
    exit 1
fi

if [ ! -d ".venv" ]; then
    echo_red "❌ 错误: 虚拟环境不存在，请先运行部署脚本创建环境"
    exit 1
fi

main
