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

# ============= 外交系统 =============

signal war_declared(attacker: String, defender: String)
signal ceasefire_signed(faction_a: String, faction_b: String)
signal treaty_signed(faction_a: String, treaty_type: String)
signal treaty_expired(faction_a: String, treaty_type: String)
signal treaty_broken(breaker: String, victim: String, treaty_type: String)
signal alliance_formed(faction_a: String, faction_b: String)
signal alliance_broken(faction_a: String, faction_b: String)
signal vassal_established(vassal: String, master: String)
signal vassal_escaped(vassal: String, master: String)
signal trade_route_opened(faction_a: String, faction_b: String)
signal opinion_changed(faction_a: String, faction_b: String, old_val: int, new_val: int)
signal reputation_changed(faction_id: String, old_val: int, new_val: int)
signal diplomacy_action_performed(action: String, actor: String, target: String)
signal negotiation_started(proposer: String, target: String)
signal negotiation_offer(proposer: String, target: String, terms: Dictionary)
signal negotiation_accepted(proposer: String, target: String)
signal negotiation_rejected(proposer: String, target: String)

# ============= 科技系统 =============

signal tech_research_started(tech_id: String)
signal tech_research_completed(tech_id: String)
signal tech_research_cancelled(tech_id: String)
signal tech_available(tech_id: String)

# ============= 城市占领系统（子任务 4） =============

## 城市归属变更时发出。new_faction 已成为 current_faction_id
signal city_occupied(city_id: String, old_faction: String, new_faction: String)

## faction 失去自己的首都时发出（占领触发）。等待迁都决策
signal capital_lost(faction_id: String, lost_city_id: String)

## faction 完成迁都（玩家手动 / AI 自动）时发出
signal capital_relocated(faction_id: String, new_capital_id: String)

## faction 灭国时发出（无任何城市 或 玩家迁都次数耗尽且首都再次失守）
signal faction_eliminated(faction_id: String)
