# vLLM + EvalScope + Unsloth 一键安装与下载脚本集

这个项目提供了一组脚本，用于安装大语言模型相关框架和下载数据集，让用户可以在AutoDL等平台快速配置开发环境。

## 文件结构

- **Infer-eval-finetune-autodl/1.install_vllm_evalscope_unsloth.sh**: 主安装脚本，安装vLLM、EvalScope和Unsloth三个框架
- **Infer-eval-finetune-autodl/2.download_data_and_models.sh**: 下载ModelScope模型和数据集

## 功能特点

- 集成安装与下载功能，执行效率更高
- 自动配置环境并安装所需依赖
- 下载 Qwen3 模型（1.7B 4比特量化版）
- 下载性能测试数据集（HC3-Chinese）
- 下载 QWEN3 模型专用评测集
- 下载 Qwen3 微调数据集集合
- 创建独立的 conda 虚拟环境（vllm、evalscope 和 unsloth）
- 实时进度显示和日志记录
- 完善的错误处理和容错机制
- 自动清理临时文件，优化磁盘空间使用
- 磁盘空间不足预警机制
- GPU环境自动检测与验证
- 带进度百分比的安装过程显示
- 智能的下载重试机制

## 安装组件

主安装脚本安装以下三个主要组件，每个组件使用独立的 conda 环境：

1. **vLLM** - 高性能的大语言模型推理框架
2. **EvalScope** - 大模型评估框架
3. **Unsloth** - 大语言模型高效微调和推理优化框架

## 数据集

下载脚本支持以下数据集:

### 评估数据集
- **HC3-Chinese** - 中文评测数据集
- **EvalScope-Qwen3-Test** - QWEN3模型专用评测集

### 微调数据集
- **qwen3-finetune-test** - Qwen3微调数据集集合，包含:
  - **OpenMathReasoning** - 数学推理任务数据集
  - **FineTome** - 通用文本指令微调数据集

## 使用方法

### 1. 安装框架

```bash
cd Infer-eval-finetune-autodl
chmod +x 1.install_vllm_evalscope_unsloth.sh
./1.install_vllm_evalscope_unsloth.sh
```

### 2. 下载模型和数据集

```bash
cd Infer-eval-finetune-autodl
chmod +x 2.download_data_and_models.sh
./2.download_data_and_models.sh
```

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

## 数据集使用

完成下载后，您可以使用以下方式加载已下载的数据集：

```python
# 从本地加载微调数据集
from datasets import load_from_disk

# 加载推理数据集
math_dataset = load_from_disk("/root/autodl-tmp/qwen3-finetune-test/OpenMathReasoning/cot")

# 加载指令微调数据集
finetome_dataset = load_from_disk("/root/autodl-tmp/qwen3-finetune-test/FineTome/train")

# 加载评估数据集
from datasets import load_from_disk

# 加载HC3数据集
hc3_dataset = load_from_disk("/root/autodl-tmp/HC3-Chinese")

# 加载EvalScope测试集
evalscope_dataset = load_from_disk("/root/autodl-tmp/EvalScope-Qwen3-Test")
```

## 日志文件

脚本执行过程中的所有输出将同时显示在终端和保存到日志文件中：

- 主安装脚本日志：`logs/install_YYYYMMDD_HHMMSS.log`
- 数据下载日志：`logs/modelscope_YYYYMMDD_HHMMSS.log`

## 注意事项

- 脚本默认将模型和数据集下载到 `/root/autodl-tmp` 目录，您可以修改脚本中的 `WORKDIR` 变量以更改存储位置
- 下载过程中如遇到网络问题，脚本会自动重试并尝试继续执行
- 如果磁盘空间极度有限，建议在确认足够空间后再执行下载脚本
- 即使没有GPU，脚本也可以正常安装和下载，只是会显示相应的警告
