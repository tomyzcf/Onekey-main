#!/bin/bash

# 颜色设置
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# 进度显示函数
show_progress() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

# 错误处理函数
handle_error() {
    echo -e "${RED}[错误] $1${NC}"
    echo -e "${YELLOW}尝试继续执行脚本...${NC}"
}

# 检查命令是否成功执行
check_success() {
    if [ $? -eq 0 ]; then
        show_progress "✓ $1成功"
    else
        handle_error "$1失败"
        if [ "$2" == "critical" ]; then
            echo -e "${RED}关键步骤失败，无法继续执行${NC}"
            exit 1
        fi
    fi
}

# 创建日志目录
mkdir -p logs
LOG_FILE="logs/install_$(date '+%Y%m%d_%H%M%S').log"
exec > >(tee -a "$LOG_FILE") 2>&1

show_progress "开始安装过程，日志将保存到 $LOG_FILE"

# ==============================================
# 1. 环境初始化
# ==============================================
show_progress "步骤1/5: 环境初始化"

show_progress "恢复默认通道顺序..."
conda config --remove-key channels || handle_error "恢复默认通道顺序"

show_progress "设置pip镜像源..."
pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple || handle_error "设置pip镜像源"

show_progress "安装基础工具..."
apt-get update && apt-get install unzip -y || handle_error "安装unzip"

show_progress "安装必要的Python包..."
pip install openai || handle_error "安装openai"
pip install modelscope || handle_error "安装modelscope" "critical"

# ==============================================
# 2. 下载必要模型和数据集
# ==============================================
show_progress "步骤2/5: 下载必要模型和数据集"

# 创建数据目录
WORKDIR="/root/autodl-tmp"
mkdir -p $WORKDIR
cd $WORKDIR || { handle_error "无法进入工作目录 $WORKDIR"; exit 1; }

show_progress "下载Qwen3模型(1.7B 4比特量化版)..."
modelscope download --model unsloth/Qwen3-1.7B-unsloth-bnb-4bit --local_dir ${WORKDIR}/Qwen3-1.7B-unsloth-bnb-4bit
check_success "下载Qwen3模型"

show_progress "下载性能测试数据集HC3-Chinese..."
modelscope download --dataset AI-ModelScope/HC3-Chinese --local_dir ${WORKDIR}/HC3-Chinese
check_success "下载HC3-Chinese数据集"

show_progress "下载QWEN3模型专用评测集..."
modelscope download --dataset modelscope/EvalScope-Qwen3-Test --local_dir ${WORKDIR}/EvalScope-Qwen3-Test
check_success "下载EvalScope-Qwen3-Test数据集"

# ==============================================
# 3. 安装vllm推理框架
# ==============================================
show_progress "步骤3/5: 安装vllm推理框架"

show_progress "创建vllm虚拟环境..."
# 检查vllm环境是否已存在
conda info --envs | grep vllm > /dev/null
if [ $? -eq 0 ]; then
    show_progress "vllm环境已存在，跳过创建"
else
    conda create --name vllm python=3.11 -y
    check_success "创建vllm环境" "critical"
fi

# 初始化conda
show_progress "初始化conda..."
conda init bash
check_success "初始化conda"

# 在脚本中使用conda命令需要以下方式
show_progress "安装vllm依赖库..."
CONDA_BASE=$(conda info --base)
source "${CONDA_BASE}/etc/profile.d/conda.sh"
conda activate vllm || { handle_error "激活vllm环境失败"; exit 1; }

pip install bitsandbytes>=0.45.3 || handle_error "安装bitsandbytes"
pip install --upgrade vllm || handle_error "安装vllm" "critical"

# ==============================================
# 4. 安装evalscope评估框架
# ==============================================
show_progress "步骤4/5: 安装evalscope评估框架"

show_progress "创建evalscope虚拟环境..."
# 检查evalscope环境是否已存在
conda info --envs | grep evalscope > /dev/null
if [ $? -eq 0 ]; then
    show_progress "evalscope环境已存在，跳过创建"
else
    conda create --name evalscope python=3.11 -y
    check_success "创建evalscope环境" "critical"
fi

show_progress "安装evalscope依赖库..."
conda activate evalscope || { handle_error "激活evalscope环境失败"; exit 1; }

show_progress "安装jupyter环境..."
conda install jupyterlab -y || handle_error "安装jupyterlab"
conda install ipykernel -y || handle_error "安装ipykernel"
python -m ipykernel install --user --name evalscope --display-name "Python evalscope" || handle_error "配置ipykernel"

show_progress "安装evalscope框架..."
pip install 'evalscope[all]' || handle_error "安装evalscope" "critical"

# ==============================================
# 5. 安装验证
# ==============================================
show_progress "步骤5/5: 安装验证"

show_progress "验证vllm安装..."
conda activate vllm || { handle_error "激活vllm环境失败"; exit 1; }
python -c "import vllm; print(f'vLLM 版本: {vllm.__version__}')"
check_success "验证vllm安装"

show_progress "验证evalscope安装..."
conda activate evalscope || { handle_error "激活evalscope环境失败"; exit 1; }
python -c "import evalscope; print(f'EvalScope 版本: {evalscope.__version__}')"
check_success "验证evalscope安装"

# ==============================================
# 安装完成
# ==============================================
echo -e "${GREEN}=================================================${NC}"
echo -e "${GREEN}安装完成！${NC}"
echo -e "${GREEN}vllm和evalscope环境已成功配置${NC}"
echo -e "${GREEN}要使用vllm，请执行: conda activate vllm${NC}"
echo -e "${GREEN}要使用evalscope，请执行: conda activate evalscope${NC}"
echo -e "${GREEN}=================================================${NC}" 