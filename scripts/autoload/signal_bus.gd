extends Node

## 全局信号总线 — 系统间解耦通信
##
## 各系统通过 SignalBus 广播事件，监听者只关心信号定义而不依赖发送方。
## 阶段 1：回合系统四信号上线。
## 阶段 2+：将追加 city_captured / unit_moved / diplomacy_changed 等。

# ============= 回合系统 =============

## 当前 faction 的回合开始时发出（GameManager 在 TURN_START → ACTION 切换之间触发）
signal turn_started(turn_number: int, faction_id: String)

## 当前 faction 的回合结束时发出（end_current_turn 执行 TURN_END 阶段时触发）
signal turn_ended(turn_number: int, faction_id: String)

## 游戏阶段切换时发出。old_phase / new_phase 取值见 GameManager.Phase
signal phase_changed(old_phase: int, new_phase: int)

## 胜利条件触发时发出。winner_faction_id 为获胜方 ID
signal game_over(winner_faction_id: String)

# ============= 事件系统 =============

## 有选项事件触发时发出，等待 UI 处理玩家选择
signal event_triggered(event_data: Dictionary)

## 事件结算后发出（效果已应用）。choice_id 为空串表示无选项事件
signal event_resolved(event_id: String, choice_id: String)
