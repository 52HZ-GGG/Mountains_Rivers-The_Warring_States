extends Node

## 全局信号总线 — 系统间解耦通信
##
## 各系统通过 SignalBus 广播事件，监听者只关心信号定义而不依赖发送方。
## 阶段 0：占位，无信号定义。
## 阶段 1+：将逐步添加 turn_started / turn_ended / city_captured / unit_moved 等信号。
