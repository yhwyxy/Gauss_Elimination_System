# 高斯消元求解高维线性方程组（分布式计算架构）

## 项目概述
该项目使用 SystemVerilog 实现了一个基于**分布式计算平台架构**的高斯消元算法，用于求解 9x9 线性方程组（Ax = b）。设计遵循客户端-服务器-计算节点架构，采用 IEEE 754 单精度浮点数（32-bit）。

## 系统架构
参照技术方案中的分布式计算平台设计：

- **主机 (Master)**：承担服务器角色，负责任务拆分、分发、协调子任务执行、验证计算结果。
- **从机1 (Forward_Elimination_Slave)**：承担计算节点角色，执行前向消元子任务，将增广矩阵转化为上三角形式。
- **从机2 (Back_Substitution_Slave)**：承担计算节点角色，执行回代求解子任务，从上三角矩阵中求出解向量。

### 通信协议
采用点对点通信（请求-应答握手）：
1. 主机将 A 矩阵和 b 向量发送给从机1，触发 `start` 信号
2. 从机1执行前向消元，完成后返回上三角矩阵 U 和变换后的 b 向量
3. 主机将 U 和 b 转发给从机2
4. 从机2回代求解后返回解向量
5. 主机完成并输出结果

## 文件结构
- `finish.sv` — 主设计文件，包含：
  - `Gauss_Elimination_System`：顶层模块，实例化主机和两个从机
  - `Master`：主机模块，状态机驱动的任务调度
  - `Forward_Elimination_Slave`：从机1，多周期前向消元状态机
  - `Back_Substitution_Slave`：从机2，多周期回代求解状态机
  - `fp_utils`：浮点运算包（`fp_add`/`fp_sub`/`fp_mul`/`fp_div`/`fp_is_zero`）
- `new_finish_testbench.sv` — 测试平台
- `matrix_data.mem` — A 矩阵数据（9x9，81 个 hex 值）
- `b_data.mem` — b 向量数据（9 个 hex 值）

## 仿真与验证

### Icarus Verilog（行为级仿真）
```bash
# 编译（-DIVERILOG_SIM 使用 real 类型浮点兜底）
iverilog -g2012 -DIVERILOG_SIM -o sim.vvp new_finish_testbench.sv finish.sv

# 运行
vvp sim.vvp
```

### Vivado xsim（综合级仿真，使用 $bitstoshortreal）
```bash
# 编译时不需要 -DIVERILOG_SIM，自动使用 $bitstoshortreal / $shortrealtobits
xelab -debug all work.tb_Gauss_Elimination_System -s sim_snap
xsim sim_snap -R
```

## 仿真结果
仿真通过，计算结果与预期解的误差在 float32 精度范围内（约 1e-5）。

预期解：
- x[0] = -0.810144, x[1] = 0.009271, x[2] = -1.008425
- x[3] = -0.615157, x[4] = -2.405083, x[5] = -1.279522
- x[6] = 1.965714,  x[7] = -0.378217, x[8] = -1.446394

## 注意事项
1. **浮点运算**：`fp_utils` 包通过条件编译支持两种实现：
   - `IVERILOG_SIM` 定义时：使用 `real` 类型手动转换（Icarus Verilog 兜底）
   - 未定义时：使用 `$bitstoshortreal` / `$shortrealtobits`（Vivado 仿真/综合前替换为 IP 核）
2. **除零检测**：从机1和从机2均在主元/对角线元素为零时置位 `error` 标志
