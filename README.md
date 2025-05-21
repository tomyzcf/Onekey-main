# vLLM + EvalScope 一键安装脚本

这个项目提供了一个一键安装脚本，用于自动化安装和配置 vLLM 推理框架和 EvalScope 评估框架，并下载相关模型和数据集。

## 功能特点

- 自动配置环境并安装所需依赖
- 下载 Qwen3 模型（1.7B 4比特量化版）
- 下载性能测试数据集（HC3-Chinese）
- 下载 QWEN3 模型专用评测集
- 创建独立的 conda 虚拟环境（vllm 和 evalscope）
- 实时进度显示和日志记录
- 完善的错误处理和容错机制
- **自动清理临时文件，优化磁盘空间使用**
- **磁盘空间不足预警机制**

## 磁盘空间管理

脚本具有智能的磁盘空间管理功能：

- 安装前检查可用磁盘空间，如果少于5GB会发出警告
- 每个主要步骤完成后自动清理临时文件
- 清理内容包括：
  - pip缓存
  - conda缓存
  - apt包管理器缓存
  - modelscope下载缓存
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

## 日志文件

安装过程中的所有输出将同时显示在终端和保存到日志文件中。日志文件保存在 `logs` 目录下，文件名格式为 `install_YYYYMMDD_HHMMSS.log`。

## 注意事项

- 脚本默认将模型和数据集下载到 `/root/autodl-tmp` 目录，您可以修改脚本中的 `WORKDIR` 变量以更改存储位置
- 安装过程中如遇到网络问题，脚本会尝试继续执行后续步骤
- 对于关键步骤失败的情况，脚本会停止执行
- 如果磁盘空间极度有限，可以考虑在下载和安装过程中分阶段执行脚本
- 脚本已针对磁盘空间有限的情况进行了优化，但仍需确保有足够空间安装所需的模型和框架
