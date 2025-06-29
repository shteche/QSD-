# QSD++

**QSD++** 是一个用于基于 高通Soc 的 Android 设备的性能优化模块。它通过 GPU 调整、CPU 扩展、I/O 调整和智能系统标志控制来增强性能和响应能力。

> 在装有 Magisk 24.0+ 的 root 设备上效果最佳。

### 特点
- 自定义 EGL 配置
- GPU 和 CPU 调节器调整
- 存储 I/O 调度器优化
- 着色器缓存和日志清理
- 自动平台 + 根类型检测
- 与 SafetyNet 无关的卸载

### 目录结构
- scripts/：所有启动时和卸载注入
- common/：可重用的逻辑，如文件完整性检查
- META-INF/：标准 Magisk 安装程序