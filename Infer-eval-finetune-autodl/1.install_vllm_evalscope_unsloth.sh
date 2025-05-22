#!/bin/bash

# 颜色设置
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# 全局变量
TOTAL_STEPS=5  # 减少步骤数
CURRENT_STEP=0

# 进度显示函数
show_progress() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    PERCENTAGE=$((CURRENT_STEP * 100 / TOTAL_STEPS))
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] [${PERCENTAGE}%] $1${NC}"
}

# 细节进度显示函数
show_detail() {
    echo -e "${BLUE}  → $1${NC}"
}

# 错误处理函数
handle_error() {
    echo -e "${RED}[错误] $1${NC}"
    echo -e "${YELLOW}尝试继续执行脚本...${NC}"
}

# 检查命令是否成功执行
check_success() {
    if [ $? -eq 0 ]; then
        show_detail "✓ $1成功"
    else
        handle_error "$1失败"
        if [ "$2" == "critical" ]; then
            echo -e "${RED}关键步骤失败，无法继续执行${NC}"
            exit 1
        fi
    fi
}

# 检查包是否已安装
is_package_installed() {
    local package_name=$1
    pip list | grep -q "$package_name"
    return $?
}

# 清理临时文件函数
cleanup_temp_files() {
    echo -e "${BLUE}[清理] 正在清理临时文件...${NC}"
    
    # 清理pip缓存
    pip cache purge
    
    # 清理conda缓存
    conda clean --all --yes
    
    # 清理apt缓存
    if command -v apt-get &> /dev/null; then
        apt-get clean
    fi
    
    # 清理下载缓存
    if [ -d ~/.cache/modelscope ]; then
        rm -rf ~/.cache/modelscope/hub/*
    fi
    
    # 清理Hugging Face缓存
    if [ -d ~/.cache/huggingface ]; then
        rm -rf ~/.cache/huggingface/hub/*
    fi
    
    # 清理系统临时文件
    find /tmp -type f -atime +1 -delete 2>/dev/null || true
    
    # 显示磁盘使用情况
    echo -e "${BLUE}[清理] 当前磁盘使用情况:${NC}"
    df -h /
}

# 检查磁盘空间
check_disk_space() {
    # 获取可用空间(KB)
    available_space=$(df -k / | awk 'NR==2 {print $4}')
    
    # 转换为GB (不使用bc，使用内建算术)
    available_space_mb=$((available_space / 1024))
    available_space_gb=$((available_space_mb / 1024))
    
    echo -e "${BLUE}[系统] 当前可用磁盘空间: ${available_space_gb} GB${NC}"
    
    # 如果可用空间小于5GB，发出警告 (使用bash内建比较)
    if [ $available_space_gb -lt 5 ]; then
        echo -e "${RED}[警告] 磁盘空间不足! 可用空间少于5GB，可能导致安装失败${NC}"
        echo -e "${YELLOW}建议在继续之前清理磁盘空间${NC}"
        
        # 询问是否继续
        read -p "是否继续安装? (y/n): " choice
        if [[ "$choice" != "y" && "$choice" != "Y" ]]; then
            echo -e "${RED}安装已取消${NC}"
            exit 1
        fi
    fi
}

# 检查GPU
check_gpu() {
    echo -e "${BLUE}[系统] 检查GPU状态...${NC}"
    
    if command -v nvidia-smi &> /dev/null; then
        nvidia-smi
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}[系统] GPU检测正常${NC}"
        else
            echo -e "${YELLOW}[警告] 发现NVIDIA驱动，但无法访问GPU信息${NC}"
        fi
    else
        echo -e "${YELLOW}[警告] 未检测到NVIDIA驱动，GPU加速将不可用${NC}"
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
show_progress "步骤1/$TOTAL_STEPS: 环境初始化"

show_detail "安装基础工具..."
apt-get update
apt-get install -y unzip bc git wget curl
check_success "安装基础工具"

show_detail "检查GPU状态..."
check_gpu

show_detail "恢复默认通道顺序..."
conda config --remove-key channels || handle_error "恢复默认通道顺序"

show_detail "设置pip镜像源..."
pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple || handle_error "设置pip镜像源"

show_detail "安装必要的Python包..."
pip install openai || handle_error "安装openai"
pip install modelscope || handle_error "安装modelscope"
pip install --upgrade datasets huggingface_hub || handle_error "安装huggingface相关库" "critical"

# 初始磁盘空间检查
check_disk_space

# 清理环境初始化后的临时文件
cleanup_temp_files
check_disk_space

# 移除创建工作目录的步骤，AutoDL默认有这个目录
echo -e "${BLUE}[提示] 请使用 2.download_data_and_models.sh 脚本下载模型和数据集${NC}"

# ==============================================
# 2. 安装vllm推理框架
# ==============================================
show_progress "步骤2/$TOTAL_STEPS: 安装vllm推理框架"

show_detail "创建vllm虚拟环境..."
# 检查vllm环境是否已存在
conda info --envs | grep vllm > /dev/null
if [ $? -eq 0 ]; then
    show_detail "vllm环境已存在，跳过创建"
else
    conda create --name vllm python=3.11 -y
    check_success "创建vllm环境" "critical"
fi

# 初始化conda
show_detail "初始化conda..."
conda init bash
check_success "初始化conda"

# 在脚本中使用conda命令需要以下方式
show_detail "安装vllm依赖库..."
CONDA_BASE=$(conda info --base)
source "${CONDA_BASE}/etc/profile.d/conda.sh"
conda activate vllm || { handle_error "激活vllm环境失败"; exit 1; }

pip install bitsandbytes>=0.45.3 || handle_error "安装bitsandbytes"
# 移除了torch安装
pip install --upgrade vllm || handle_error "安装vllm" "critical"

show_detail "安装nltk并下载必要数据..."
pip install nltk || handle_error "安装nltk"
python -c "import nltk; nltk.download('punkt'); nltk.download('punkt_tab'); nltk.download('omw-1.4'); nltk.download('wordnet'); nltk.download('stopwords')" || handle_error "下载nltk数据"

# 清理vllm安装后的临时文件
conda deactivate
cleanup_temp_files
check_disk_space

# ==============================================
# 3. 安装evalscope评估框架
# ==============================================
show_progress "步骤3/$TOTAL_STEPS: 安装evalscope评估框架"

show_detail "创建evalscope虚拟环境..."
# 检查evalscope环境是否已存在
conda info --envs | grep evalscope > /dev/null
if [ $? -eq 0 ]; then
    show_detail "evalscope环境已存在，跳过创建"
else
    conda create --name evalscope python=3.11 -y
    check_success "创建evalscope环境" "critical"
fi

show_detail "安装evalscope依赖库..."
conda activate evalscope || { handle_error "激活evalscope环境失败"; exit 1; }

show_detail "安装jupyter环境..."
conda install jupyterlab -y || handle_error "安装jupyterlab"
conda install ipykernel -y || handle_error "安装ipykernel"
python -m ipykernel install --user --name evalscope --display-name "Python evalscope" || handle_error "配置ipykernel"

show_detail "安装evalscope框架..."
pip install 'evalscope[all]' || handle_error "安装evalscope" "critical"

show_detail "安装nltk并下载必要数据..."
pip install nltk || handle_error "安装nltk"
python -c "import nltk; nltk.download('punkt'); nltk.download('punkt_tab'); nltk.download('omw-1.4'); nltk.download('wordnet'); nltk.download('stopwords')" || handle_error "下载nltk数据"

# 清理evalscope安装后的临时文件
conda deactivate
cleanup_temp_files
check_disk_space

# ==============================================
# 4. 安装Unsloth
# ==============================================
show_progress "步骤4/$TOTAL_STEPS: 安装Unsloth"

# 执行额外的空间清理
show_detail "为Unsloth安装准备空间，执行深度清理..."
# 清理conda未使用的包
conda clean --all --yes
# 删除不必要的下载缓存
rm -rf ~/.cache/pip/* 2>/dev/null || true
rm -rf ~/.cache/huggingface/* 2>/dev/null || true
# 显示清理后的空间
df -h /
check_disk_space

show_detail "创建unsloth虚拟环境..."
# 检查unsloth环境是否已存在
conda info --envs | grep unsloth > /dev/null
if [ $? -eq 0 ]; then
    show_detail "unsloth环境已存在，跳过创建"
else
    # 创建新的环境
    conda create --name unsloth python=3.11 -y
    check_success "创建unsloth环境" "critical"
fi

show_detail "安装Unsloth依赖库..."
conda activate unsloth || { handle_error "激活unsloth环境失败"; exit 1; }

show_detail "安装jupyter环境..."
conda install jupyterlab -y || handle_error "安装jupyterlab"
conda install ipykernel -y || handle_error "安装ipykernel"
python -m ipykernel install --user --name unsloth --display-name "Python unsloth" || handle_error "配置ipykernel"

# 安装Unsloth和数据集访问库
show_detail "安装Unsloth框架和数据集访问库..."
pip install --upgrade --force-reinstall --no-cache-dir unsloth unsloth_zoo || handle_error "安装Unsloth" "critical"
pip install --upgrade datasets huggingface_hub || handle_error "安装huggingface相关库" 

show_detail "安装nltk并下载必要数据..."
pip install nltk || handle_error "安装nltk"
python -c "import nltk; nltk.download('punkt'); nltk.download('punkt_tab'); nltk.download('omw-1.4'); nltk.download('wordnet'); nltk.download('stopwords')" || handle_error "下载nltk数据"

# 清理Unsloth安装后的临时文件
conda deactivate
cleanup_temp_files
check_disk_space

# ==============================================
# 5. 安装验证
# ==============================================
show_progress "步骤5/$TOTAL_STEPS: 安装验证和测试"

show_detail "验证vllm安装..."
conda activate vllm || { handle_error "激活vllm环境失败"; exit 1; }
python -c "import vllm; print(f'vLLM 版本: {vllm.__version__}')"
check_success "验证vllm安装"

show_detail "验证evalscope安装..."
conda activate evalscope || { handle_error "激活evalscope环境失败"; exit 1; }
python -c "import evalscope; print(f'EvalScope 版本: {evalscope.__version__}')"
check_success "验证evalscope安装"

show_detail "验证Unsloth安装..."
conda activate unsloth || { handle_error "激活unsloth环境失败"; exit 1; }
python -c "from unsloth import __version__; print(f'Unsloth 版本: {__version__}')" || echo "Unsloth已安装，但无法获取版本号"
python -c "from datasets import __version__ as ds_version; print(f'Datasets 版本: {ds_version}')"
check_success "验证Unsloth安装"

# 最终清理
conda deactivate
cleanup_temp_files

# 显示安装前后的磁盘使用情况对比
show_progress "完成所有安装和清理"
df -h /

# ==============================================
# 安装完成
# ==============================================
echo -e "${GREEN}=================================================${NC}"
echo -e "${GREEN}安装完成！${NC}"
echo -e "${GREEN}vllm、evalscope和Unsloth环境已成功配置${NC}"
echo -e "${GREEN}要使用vllm，请执行: conda activate vllm${NC}"
echo -e "${GREEN}要使用evalscope，请执行: conda activate evalscope${NC}"
echo -e "${GREEN}要使用Unsloth，请执行: conda activate unsloth${NC}"
echo -e "${GREEN}=================================================${NC}"
echo -e "${PURPLE}如需下载模型和数据集，请使用以下脚本:${NC}"
echo -e "${PURPLE}- 下载模型和数据集: 2.download_data_and_models.sh${NC}"
echo -e "${GREEN}=================================================${NC}" 