# vLLM + EvalScope + Unsloth 一键安装脚本

这个项目提供了一个一键安装脚本，用于自动化安装和配置 vLLM 推理框架、EvalScope 评估框架和 Unsloth 优化框架，并下载相关模型和数据集。

## 功能特点

- 自动配置环境并安装所需依赖
- 下载 Qwen3 模型（1.7B 4比特量化版）
- 下载性能测试数据集（HC3-Chinese）
- 下载 QWEN3 模型专用评测集
- **下载微调数据集（推理和非推理）的特定分片**
- 创建独立的 conda 虚拟环境（vllm、evalscope 和 unsloth）
- 实时进度显示和日志记录
- 完善的错误处理和容错机制
- **自动清理临时文件，优化磁盘空间使用**
- **磁盘空间不足预警机制**

## 安装组件

脚本安装以下三个主要组件，每个组件使用独立的 conda 环境：

1. **vLLM** - 高性能的大语言模型推理框架
2. **EvalScope** - 大模型评估框架
3. **Unsloth** - 大语言模型高效微调和推理优化框架

## 数据集

脚本下载以下数据集:

### 评估数据集
- **HC3-Chinese** - 中文评测数据集
- **EvalScope-Qwen3-Test** - QWEN3模型专用评测集

### 微调数据集
- **OpenMathReasoning-mini (cot分片)** - 推理任务数据集 (来自HuggingFace `unsloth/OpenMathReasoning-mini`)
- **FineTome-100k (train分片)** - 非推理任务数据集 (来自HuggingFace `mlabonne/FineTome-100k`)

这些微调数据集只下载特定的分片，以节省空间并提高下载速度。数据集使用`datasets`库的`save_to_disk`方法保存到本地。

## 磁盘空间管理

脚本具有智能的磁盘空间管理功能：

- 安装前检查可用磁盘空间，如果少于5GB会发出警告
- 每个主要步骤完成后自动清理临时文件
- Unsloth 安装前执行额外的深度清理
- 清理内容包括：
  - pip缓存
  - conda缓存
  - apt包管理器缓存
  - modelscope下载缓存
  - huggingface缓存
  - 系统临时文件
- 显示安装各阶段的磁盘使用情况

## 使用方法

### Linux 环境

1. 下载脚本：
   ```bash
   wget https://raw.githubusercontent.com/your-username/your-repo/main/install_vllm_evalscope_autodl.sh
   ```

2. 添加执行权限：
   ```bash
   chmod +x install_vllm_evalscope_autodl.sh
   ```

3. 运行脚本：
   ```bash
   ./install_vllm_evalscope_autodl.sh
   ```

### Windows 环境

在 Windows 环境中，您可以通过以下步骤使用该脚本：

1. 安装 WSL（Windows Subsystem for Linux）或使用 Git Bash
2. 按照 Linux 环境的步骤操作

或者，您可以在 PowerShell 中逐条执行脚本中的等效命令。

## 安装完成后

安装完成后，您可以通过以下命令激活相应的环境：

- 使用 vLLM 环境：
  ```bash
  conda activate vllm
  ```

- 使用 EvalScope 环境：
  ```bash
  conda activate evalscope
  ```

- 使用 Unsloth 环境：
  ```bash
  conda activate unsloth
  ```

## 微调数据集使用

完成安装后，您可以使用以下方式加载已下载的微调数据集：

```python
# 直接从在线加载（任何环境都可以）
from datasets import load_dataset

# 加载推理数据集的cot分片
reasoning_dataset = load_dataset("unsloth/OpenMathReasoning-mini", split="cot")

# 加载非推理数据集的train分片
non_reasoning_dataset = load_dataset("mlabonne/FineTome-100k", split="train")

# 加载本地保存的数据集（推荐，更快）
from datasets import load_from_disk

local_reasoning_dataset = load_from_disk("/root/autodl-tmp/finetune_datasets/OpenMathReasoning-mini/cot")
local_non_reasoning_dataset = load_from_disk("/root/autodl-tmp/finetune_datasets/FineTome-100k/train")
```

## 日志文件

安装过程中的所有输出将同时显示在终端和保存到日志文件中。日志文件保存在 `logs` 目录下，文件名格式为 `install_YYYYMMDD_HHMMSS.log`。

## 注意事项

- 脚本默认将模型和数据集下载到 `/root/autodl-tmp` 目录，您可以修改脚本中的 `WORKDIR` 变量以更改存储位置
- 微调数据集保存在 `/root/autodl-tmp/finetune_datasets` 目录，按分片存储
- 安装过程中如遇到网络问题，脚本会尝试继续执行后续步骤
- 对于关键步骤失败的情况，脚本会停止执行
- 如果磁盘空间极度有限，可以考虑在下载和安装过程中分阶段执行脚本
- 脚本已针对磁盘空间有限的情况进行了优化，但仍需确保有足够空间安装所需的模型和框架
