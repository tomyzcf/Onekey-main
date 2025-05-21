#!/bin/bash

# 可配置变量 - 便于调整
WORKDIR="/root/autodl-tmp"

# 颜色设置
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# 进度显示函数
show_progress() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

# 细节进度显示函数
show_detail() {
    echo -e "${BLUE}  → $1${NC}"
}

# 错误处理函数
handle_error() {
    echo -e "${RED}[错误] $1${NC}"
}

# 检查磁盘空间
check_disk_space() {
    # 获取可用空间(KB)
    available_space=$(df -k / | awk 'NR==2 {print $4}')
    
    # 转换为GB
    available_space_mb=$((available_space / 1024))
    available_space_gb=$((available_space_mb / 1024))
    
    echo -e "${BLUE}[系统] 当前可用磁盘空间: ${available_space_gb} GB${NC}"
    
    # 如果可用空间小于10GB，发出警告
    if [ $available_space_gb -lt 10 ]; then
        echo -e "${RED}[警告] 磁盘空间不足! 可用空间少于10GB，可能导致下载失败${NC}"
        
        # 询问是否继续
        read -p "是否继续下载? (y/n): " choice
        if [[ "$choice" != "y" && "$choice" != "Y" ]]; then
            echo -e "${RED}下载已取消${NC}"
            exit 1
        fi
    fi
}

# 清理缓存
cleanup_cache() {
    show_detail "清理下载缓存..."
    
    # 清理modelscope缓存
    if [ -d ~/.cache/modelscope ]; then
        rm -rf ~/.cache/modelscope/hub/*
    fi
    
    echo -e "${BLUE}[清理] 当前磁盘使用情况:${NC}"
    df -h /
}

# 带重试的下载函数
download_with_retry() {
    local command="$1"
    local description="$2"
    local max_retries=3
    local retry_count=0
    
    while [ $retry_count -lt $max_retries ]; do
        show_detail "尝试下载 $description (尝试 $((retry_count+1))/$max_retries)"
        if eval "$command"; then
            show_detail "✓ $description 下载成功"
            return 0
        else
            retry_count=$((retry_count+1))
            if [ $retry_count -lt $max_retries ]; then
                echo -e "${YELLOW}[重试] 下载失败，等待10秒后重试...${NC}"
                sleep 10
            else
                handle_error "$description 下载失败，已达到最大重试次数"
                return 1
            fi
        fi
    done
}

# 创建日志目录
mkdir -p logs
LOG_FILE="logs/modelscope_$(date '+%Y%m%d_%H%M%S').log"
exec > >(tee -a "$LOG_FILE") 2>&1

show_progress "开始下载ModelScope模型和数据集，日志将保存到 $LOG_FILE"

# 检查pip是否安装了modelscope
if ! command -v pip &> /dev/null || ! pip list | grep -q modelscope; then
    show_progress "安装ModelScope..."
    pip install modelscope
fi

# 检查磁盘空间
check_disk_space

# 创建工作目录
mkdir -p $WORKDIR
cd $WORKDIR || { handle_error "无法进入工作目录 $WORKDIR"; exit 1; }

show_progress "下载Qwen3模型(1.7B 4比特量化版)..."
download_with_retry "modelscope download --model unsloth/Qwen3-1.7B-unsloth-bnb-4bit --local_dir ${WORKDIR}/Qwen3-1.7B-unsloth-bnb-4bit" "Qwen3模型"

# 清理缓存
cleanup_cache

show_progress "下载性能测试数据集HC3-Chinese..."
download_with_retry "modelscope download --dataset AI-ModelScope/HC3-Chinese --local_dir ${WORKDIR}/HC3-Chinese" "HC3-Chinese数据集"

# 清理缓存
cleanup_cache

show_progress "下载QWEN3模型专用评测集..."
download_with_retry "modelscope download --dataset modelscope/EvalScope-Qwen3-Test --local_dir ${WORKDIR}/EvalScope-Qwen3-Test" "EvalScope-Qwen3-Test数据集"

# 清理缓存
cleanup_cache

show_progress "下载Qwen3微调数据集集合..."
download_with_retry "modelscope download --dataset tomyzcf/qwen3-finetune-test --local_dir ${WORKDIR}/qwen3-finetune-test" "Qwen3微调数据集"

# 清理缓存
cleanup_cache

# 显示下载内容
show_progress "下载完成"
echo -e "${PURPLE}已下载的内容:${NC}"
echo -e "${PURPLE}1. 模型:${NC}"
echo -e "${PURPLE}   - Qwen3-1.7B-unsloth-bnb-4bit: $(du -sh ${WORKDIR}/Qwen3-1.7B-unsloth-bnb-4bit 2>/dev/null || echo '未找到')${NC}"
echo -e "${PURPLE}2. 评估数据集:${NC}"
echo -e "${PURPLE}   - HC3-Chinese: $(du -sh ${WORKDIR}/HC3-Chinese 2>/dev/null || echo '未找到')${NC}"
echo -e "${PURPLE}   - EvalScope-Qwen3-Test: $(du -sh ${WORKDIR}/EvalScope-Qwen3-Test 2>/dev/null || echo '未找到')${NC}"
echo -e "${PURPLE}3. 微调数据集:${NC}"
echo -e "${PURPLE}   - qwen3-finetune-test: $(du -sh ${WORKDIR}/qwen3-finetune-test 2>/dev/null || echo '未找到')${NC}"
echo -e "${GREEN}所有内容已下载至: ${WORKDIR}${NC}"
echo -e "${GREEN}日志文件: ${LOG_FILE}${NC}" 