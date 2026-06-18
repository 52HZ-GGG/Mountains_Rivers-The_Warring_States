# 随机事件系统重设计

> **日期**：2026-05-16
> **版本**：v2.0
> **状态**：设计确认，待实施
> **替代**：`docs/机制概览/随机事件系统.md` v1.2

---

## 1. 设计目标

- 每回合事件触发数量可控，不打断玩家节奏
- 纵横家事件链作为特殊叙事线，必定触发且独立于普通事件
- 事件优先级有明确规则，策划可预期每回合结果
- 历史事件只触发一次，增强稀缺感和代入感
- 保留条件+概率双重判定的悬念感

---

## 2. 整体触发流程

每回合 `turn_start` 信号触发后，EventManager 按以下三阶段串行执行：

### 阶段 1：链式事件

- 检查当前激活的事件链（纵横家）
- 条件满足 → 必定触发（无视概率、无视分池）
- 推进链指针到下一节点
- 每条链每回合最多推进 1 步

### 阶段 2：季节事件

- 检查当前季节对应的季节事件
- 概率 1.0，必定触发
- 占用季节类分池名额

### 阶段 3：分池竞争

按类型优先级从高到低处理：

```
政治(90) → 外交(70) → 军事(60) → 特殊(50) → 学派(40) → 经济(30) → 民心(20)
```

每个类型内部：

1. 收集满足条件且不在冷却中的事件
2. 各自掷概率骰（`randf() <= probability`）
3. 命中者中取优先级最高者触发（每类最多 1 条）

已被阶段 1/2 占用的类型跳过。

---

## 3. 优先级系统

### 3.1 类型优先级

| 优先级 | 类型 | 说明 |
|:---:|:---|:---|
| 100 | event_chain（纵横家链） | 独立于分池，阶段 1 处理 |
| 90 | politics（政治） | 商鞅变法等，国家战略级 |
| 80 | season（季节） | 阶段 2 处理，概率 1.0 |
| 70 | diplomacy（外交） | 合纵连横等 |
| 60 | military（军事） | 匪寇、历史战役 |
| 50 | special（特殊） | 完璧归赵等历史典故 |
| 40 | school（学派） | 六学派专属事件 |
| 30 | economy（经济） | 天灾、丰收、商业 |
| 20 | morale（民心） | 祭祀、瘟疫、民怨 |

### 3.2 同类型内事件优先级

同类内部有多个事件命中时，取 `trigger.priority` 数值最高者。若优先级也相同，随机选取。

每个事件在 JSON 中定义 `trigger.priority`（整数，越大越优先），用于同类型内的事件竞争。

---

## 4. 差异化冷却

### 4.1 冷却规则

| 类型 | 冷却回合 | 说明 |
|:---|:---:|:---|
| event_chain | 0 | 链式事件不冷却，按链指针推进 |
| politics | 999 | 历史政治事件只触发一次 |
| season | 0 | 季节事件每季必定触发，无需冷却 |
| special | 999 | 历史典故只触发一次 |
| military（历史战役） | 999 | 历史战役只触发一次 |
| military（普通） | 3 | 普通军事事件 3 回合冷却 |
| diplomacy（历史） | 999 | 历史外交只触发一次 |
| diplomacy（链式） | 0 | 按链指针推进 |
| diplomacy（普通） | 3 | 普通外交事件 3 回合冷却 |
| school | 3 | 学派事件 3 回合冷却 |
| economy | 3 | 经济事件 3 回合冷却 |
| morale | 3 | 民心事件 3 回合冷却 |

### 4.2 实现方式

- 在事件 JSON 中增加 `trigger.one_shot: true` 标记（历史事件只触发一次）
- `one_shot: true` 的事件触发后冷却设为 999，永不再触发
- 普通事件保持 `cooldown_turns: 3`（从 `balance_params.json` 读取）
- 冷却值在 `turn_ended` 时递减

---

## 5. 纵横家事件链机制

### 5.1 链结构定义

在 `events.json` 中新增顶层字段 `event_chains`：

```json
{
  "schema_version": "2.0",
  "events": [...],
  "event_chains": [
    {
      "id": "chain_suqin_hezong",
      "name": "苏秦合纵",
      "faction": "qi",
      "nodes": [
        {
          "event_id": "dip_suqin_emerge",
          "conditions": { "turn_min": 10 },
          "next": "dip_hezong_proposal"
        },
        {
          "event_id": "dip_hezong_proposal",
          "conditions": { "turn_min": 12 },
          "next": "dip_hezong_conflict"
        },
        {
          "event_id": "dip_hezong_conflict",
          "conditions": { "turn_min": 18 },
          "next": "dip_hezong_collapse"
        },
        {
          "event_id": "dip_hezong_collapse",
          "conditions": { "turn_min": 20 },
          "next": null
        }
      ]
    },
    {
      "id": "chain_zhangyi_lianheng",
      "name": "张仪连横",
      "faction": "qin",
      "nodes": [
        {
          "event_id": "dip_zhangyi_enter_qin",
          "conditions": { "turn_min": 8 },
          "next": "dip_lianheng_plan"
        },
        {
          "event_id": "dip_lianheng_plan",
          "conditions": { "turn_min": 10 },
          "next": "dip_lianheng_backlash"
        },
        {
          "event_id": "dip_lianheng_backlash",
          "conditions": { "turn_min": 14 },
          "next": "dip_lianheng_break"
        },
        {
          "event_id": "dip_lianheng_break",
          "conditions": { "turn_min": 16 },
          "next": null
        }
      ]
    }
  ]
}
```

### 5.2 推进逻辑

- 链有 `current_node` 指针，初始指向第一个节点
- 每回合阶段 1 检查：当前节点条件满足 → 必定触发 → 指针推进到 `next`
- `next: null` 表示链结束
- 链式事件触发后不进入冷却（冷却由链指针控制）
- 多条链可并行存在，每条链每回合最多推进 1 步
- 链的 `faction` 字段限定该链只对玩家选择的势力生效

### 5.3 公孙衍事件

`dip_gongsun_persuade`（公孙衍游说）不属于特定事件链，作为普通外交事件处理（概率触发、3 回合冷却）。

---

## 6. Schema 变更

### 6.1 events.json 变更

**事件对象新增字段**：

| 字段 | 位置 | 类型 | 默认值 | 说明 |
|:---|:---|:---|:---|:---|
| `trigger.priority` | trigger 内 | int | 50 | 同类型内事件优先级 |
| `trigger.one_shot` | trigger 内 | bool | false | 是否只触发一次 |

**新增顶层字段**：

| 字段 | 类型 | 说明 |
|:---|:---|:---|
| `event_chains` | Array[EventChain] | 事件链定义 |

### 6.2 balance_params.json 变更

新增字段：

```json
{
  "event_cooldown_by_type": {
    "economy": 3,
    "military": 3,
    "morale": 3,
    "school": 3,
    "diplomacy": 3,
    "special": 999,
    "politics": 999,
    "season": 0,
    "event_chain": 0
  }
}
```

---

## 7. EventManager 接口变更

### 7.1 新增方法

| 方法 | 返回 | 说明 |
|:---|:---|:---|
| `get_active_chains()` | Array[Dictionary] | 获取当前激活的事件链状态 |
| `advance_chain(chain_id)` | void | 手动推进指定事件链（调试用） |

### 7.2 修改方法

| 方法 | 变更说明 |
|:---|:---|
| `_check_and_trigger_events()` | 重构为三阶段流水线 |
| `_check_conditions()` | 实现所有待实现条件（school/at_war/has_alliance/allies_min） |
| `_is_on_cooldown()` | 支持 one_shot 事件的永不过期冷却 |
| `_trigger_event()` | 链式事件触发后推进链指针 |

### 7.3 新增信号

| 信号 | 参数 | 时机 |
|:---|:---|:---|
| `chain_advanced` | `chain_id: String, event_id: String` | 事件链推进时 |
| `chain_completed` | `chain_id: String` | 事件链完结时 |

---

## 8. 待实现条件补全

当前 5 种条件未实现且默认通过，需在本次重设计中一并实现：

| 条件 | 实现方式 |
|:---|:---|
| `school` | 调用 `GameManager.get_current_school()` 比对 |
| `at_war` | 调用 `DiplomacySystem.is_at_war()` 比对 |
| `has_alliance` | 调用 `DiplomacySystem.has_alliance()` 比对 |
| `allies_min` | 调用 `DiplomacySystem.get_allies_count()` 比对 |
| `troops_in_hex_range` | 调用 `GameManager.get_units_in_range()` 比对（复杂，可延后） |

---

## 9. 事件清单调整

### 9.1 从普通事件移入事件链的事件

以下事件不再作为独立事件参与分池竞争，改为由事件链驱动：

| 原事件 ID | 归属链 |
|:---|:---|
| `dip_suqin_emerge` | chain_suqin_hezong |
| `dip_hezong_proposal` | chain_suqin_hezong |
| `dip_hezong_conflict` | chain_suqin_hezong |
| `dip_hezong_collapse` | chain_suqin_hezong |
| `dip_zhangyi_enter_qin` | chain_zhangyi_lianheng |
| `dip_lianheng_plan` | chain_zhangyi_lianheng |
| `dip_lianheng_backlash` | chain_zhangyi_lianheng |
| `dip_lianheng_break` | chain_zhangyi_lianheng |

### 9.2 one_shot 事件标记

以下事件标记为 `one_shot: true`：

- 所有 `hist_` 前缀事件（历史事件）
- `politics` 类型全部事件
- `special` 类型全部事件

### 9.3 季节事件

3 个季节事件（`evt_spring_farming`、`evt_harsh_winter`、`evt_bumper_year`）保持概率 1.0，每季必定触发。

---

## 10. 不在本次范围内

- 事件 UI 面板（需单独设计）
- AI 事件处理（仅触发玩家势力）
- `troops_in_hex_range` 条件（复杂度高，延后）
- 事件链分支机制（当前仅支持线性链）
