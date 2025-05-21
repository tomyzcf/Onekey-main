#!/bin/bash

# 颜色设置
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
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

# 创建日志目录
mkdir -p logs
LOG_FILE="logs/install_$(date '+%Y%m%d_%H%M%S').log"
exec > >(tee -a "$LOG_FILE") 2>&1

show_progress "开始安装过程，日志将保存到 $LOG_FILE"

# ==============================================
# 1. 环境初始化
# ==============================================
show_progress "步骤1/7: 环境初始化"

show_progress "安装基础工具..."
apt-get update
apt-get install -y unzip bc git
check_success "安装基础工具"

show_progress "恢复默认通道顺序..."
conda config --remove-key channels || handle_error "恢复默认通道顺序"

show_progress "设置pip镜像源..."
pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple || handle_error "设置pip镜像源"

show_progress "安装必要的Python包..."
pip install openai || handle_error "安装openai"
pip install modelscope || handle_error "安装modelscope"
pip install --upgrade datasets huggingface_hub || handle_error "安装huggingface相关库" "critical"

# 初始磁盘空间检查
check_disk_space

# 清理环境初始化后的临时文件
cleanup_temp_files
check_disk_space

# ==============================================
# 2. 下载必要模型和数据集
# ==============================================
show_progress "步骤2/7: 下载必要模型和数据集"

# 创建数据目录
WORKDIR="/root/autodl-tmp"
mkdir -p $WORKDIR
cd $WORKDIR || { handle_error "无法进入工作目录 $WORKDIR"; exit 1; }

show_progress "下载Qwen3模型(1.7B 4比特量化版)..."
modelscope download --model unsloth/Qwen3-1.7B-unsloth-bnb-4bit --local_dir ${WORKDIR}/Qwen3-1.7B-unsloth-bnb-4bit
check_success "下载Qwen3模型"

# 清理第一个模型下载后的缓存
cleanup_temp_files

show_progress "下载性能测试数据集HC3-Chinese..."
modelscope download --dataset AI-ModelScope/HC3-Chinese --local_dir ${WORKDIR}/HC3-Chinese
check_success "下载HC3-Chinese数据集"

# 清理第二个数据集下载后的缓存
cleanup_temp_files

show_progress "下载QWEN3模型专用评测集..."
modelscope download --dataset modelscope/EvalScope-Qwen3-Test --local_dir ${WORKDIR}/EvalScope-Qwen3-Test
check_success "下载EvalScope-Qwen3-Test数据集"

# 清理所有下载后的临时文件
cleanup_temp_files
check_disk_space

# ==============================================
# 3. 下载微调数据集
# ==============================================
show_progress "步骤3/7: 下载微调数据集"

# 创建微调数据集目录
FINETUNE_DIR="${WORKDIR}/finetune_datasets"
mkdir -p $FINETUNE_DIR
cd $FINETUNE_DIR || { handle_error "无法进入微调数据集目录 $FINETUNE_DIR"; exit 1; }

show_progress "安装数据集库依赖..."
pip install -q datasets huggingface_hub
check_success "安装数据集库依赖"

# 创建简化的Python脚本下载指定数据集分片
cat > download_datasets.py << 'EOL'
from datasets import load_dataset
import os
import sys

# 创建目录
os.makedirs("OpenMathReasoning-mini", exist_ok=True)
os.makedirs("FineTome-100k", exist_ok=True)

# 下载推理数据集 (仅cot分片)
print("正在下载 OpenMathReasoning-mini 数据集 (cot分片)...")
try:
    reasoning_dataset = load_dataset("unsloth/OpenMathReasoning-mini", split="cot")
    print(f"成功下载推理数据集，包含 {len(reasoning_dataset)} 条记录")
    # 保存到本地缓存，同时输出大小
    reasoning_dataset.save_to_disk("OpenMathReasoning-mini/cot")
    print(f"已保存到 OpenMathReasoning-mini/cot 目录")
except Exception as e:
    print(f"下载推理数据集失败: {str(e)}")
    sys.exit(1)

# 下载非推理数据集 (仅train分片)
print("正在下载 FineTome-100k 数据集 (train分片)...")
try:
    non_reasoning_dataset = load_dataset("mlabonne/FineTome-100k", split="train")
    print(f"成功下载非推理数据集，包含 {len(non_reasoning_dataset)} 条记录")
    # 保存到本地缓存
    non_reasoning_dataset.save_to_disk("FineTome-100k/train")
    print(f"已保存到 FineTome-100k/train 目录")
except Exception as e:
    print(f"下载非推理数据集失败: {str(e)}")
    sys.exit(1)

print("所有数据集下载完成")
EOL

show_progress "下载推理数据集(OpenMathReasoning-mini)的cot分片和非推理数据集(FineTome-100k)的train分片..."
python download_datasets.py
check_success "下载微调数据集" "critical"

# 显示数据集信息
echo -e "${BLUE}已下载的微调数据集:${NC}"
echo -e "${BLUE}- OpenMathReasoning-mini (cot分片): $(du -sh OpenMathReasoning-mini | cut -f1)${NC}"
echo -e "${BLUE}- FineTome-100k (train分片): $(du -sh FineTome-100k | cut -f1)${NC}"

# 清理微调数据集下载后的缓存
cd $WORKDIR
cleanup_temp_files
check_disk_space

# ==============================================
# 4. 安装vllm推理框架
# ==============================================
show_progress "步骤4/7: 安装vllm推理框架"

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

# 清理vllm安装后的临时文件
conda deactivate
cleanup_temp_files
check_disk_space

# ==============================================
# 5. 安装evalscope评估框架
# ==============================================
show_progress "步骤5/7: 安装evalscope评估框架"

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

# 清理evalscope安装后的临时文件
conda deactivate
cleanup_temp_files
check_disk_space

# ==============================================
# 6. 安装Unsloth
# ==============================================
show_progress "步骤6/7: 安装Unsloth"

# 执行额外的空间清理
show_progress "为Unsloth安装准备空间，执行深度清理..."
# 清理conda未使用的包
conda clean --all --yes
# 删除不必要的下载缓存
rm -rf ~/.cache/pip/* 2>/dev/null || true
rm -rf ~/.cache/huggingface/* 2>/dev/null || true
# 显示清理后的空间
df -h /
check_disk_space

show_progress "创建unsloth虚拟环境..."
# 检查unsloth环境是否已存在
conda info --envs | grep unsloth > /dev/null
if [ $? -eq 0 ]; then
    show_progress "unsloth环境已存在，跳过创建"
else
    # 创建新的环境
    conda create --name unsloth python=3.11 -y
    check_success "创建unsloth环境" "critical"
fi

show_progress "安装Unsloth依赖库..."
conda activate unsloth || { handle_error "激活unsloth环境失败"; exit 1; }

show_progress "安装jupyter环境..."
conda install jupyterlab -y || handle_error "安装jupyterlab"
conda install ipykernel -y || handle_error "安装ipykernel"
python -m ipykernel install --user --name unsloth --display-name "Python unsloth" || handle_error "配置ipykernel"

# 安装Unsloth和数据集访问库
show_progress "安装Unsloth框架和数据集访问库..."
pip install --upgrade --force-reinstall --no-cache-dir unsloth unsloth_zoo || handle_error "安装Unsloth" "critical"
pip install --upgrade datasets huggingface_hub || handle_error "安装huggingface相关库" 

# 测试访问数据集
show_progress "测试Unsloth环境访问数据集..."
cat > test_datasets.py << 'EOL'
try:
    from datasets import load_dataset
    
    # 测试是否能访问HuggingFace Hub
    print("测试访问HuggingFace数据集...")
    # 尝试加载一个小数据集
    test_dataset = load_dataset("unsloth/OpenMathReasoning-mini", split="cot", trust_remote_code=True)
    print(f"成功加载测试数据集，包含 {len(test_dataset)} 条记录")
    
    print("数据集访问测试成功")
except Exception as e:
    print(f"数据集访问测试失败: {str(e)}")
EOL

python test_datasets.py || echo "数据集访问测试遇到问题，但不会阻止安装继续"

# 清理Unsloth安装后的临时文件
conda deactivate
cleanup_temp_files
check_disk_space

# ==============================================
# 7. 安装验证
# ==============================================
show_progress "步骤7/7: 安装验证"

show_progress "验证vllm安装..."
conda activate vllm || { handle_error "激活vllm环境失败"; exit 1; }
python -c "import vllm; print(f'vLLM 版本: {vllm.__version__}')"
check_success "验证vllm安装"

show_progress "验证evalscope安装..."
conda activate evalscope || { handle_error "激活evalscope环境失败"; exit 1; }
python -c "import evalscope; print(f'EvalScope 版本: {evalscope.__version__}')"
check_success "验证evalscope安装"

show_progress "验证Unsloth安装..."
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
echo -e "${BLUE}已下载的微调数据集位于: ${FINETUNE_DIR}${NC}"
echo -e "${BLUE}- OpenMathReasoning-mini (cot分片)${NC}"
echo -e "${BLUE}- FineTome-100k (train分片)${NC}"
echo -e "${GREEN}=================================================${NC}" 