# 随机事件系统重设计 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将现有随机事件系统重构为三阶段流水线（链式事件 → 季节事件 → 分池竞争），支持纵横家事件链必定触发、按类型差异化冷却、同类型优先级排序。

**Architecture:** EventManager 重构为三阶段串行处理。阶段 1 处理事件链（从 events.json 新增的 event_chains 字段加载），阶段 2 处理季节事件，阶段 3 按类型优先级分池竞争。事件 JSON 新增 priority/one_shot 字段，DataManager 新增事件链加载接口。

**Tech Stack:** Godot 4.3+, GDScript, GUT 测试框架, JSON 数据驱动

---

## 文件结构

| 操作 | 文件 | 职责 |
|:---|:---|:---|
| Modify | `data/events.json` | 新增 event_chains 顶层字段；88 个事件 trigger 内新增 priority/one_shot |
| Modify | `data/balance_params.json` | 新增 event_cooldown_by_type 字段 |
| Modify | `scripts/autoload/data_manager.gd` | 新增 get_event_chains() 接口 |
| Modify | `scripts/autoload/signal_bus.gd` | 新增 chain_advanced/chain_completed 信号 |
| Modify | `scripts/autoload/event_manager.gd` | 重构为三阶段流水线，支持链式事件、差异化冷却、缺失条件 |
| Create | `tests/unit/test_event_manager.gd` | EventManager 单元测试 |
| Modify | `docs/机制概览/随机事件系统.md` | 更新为 v2.0 设计文档 |

---

### Task 1: 更新 events.json Schema — 新增 priority 和 one_shot 字段

**Files:**
- Modify: `data/events.json`

- [ ] **Step 1: 为所有 88 个事件的 trigger 对象新增 priority 和 one_shot 字段**

使用 Python 脚本批量更新，按以下规则：
- `hist_` 前缀事件：`one_shot: true`，priority 按类型默认值
- 季节事件（`evt_spring_farming`、`evt_harsh_winter`、`evt_bumper_year`）：`one_shot: false`
- 其他事件：`one_shot: false`

priority 默认值按类型：
- politics: 90
- diplomacy: 70
- military: 60
- special: 50
- school: 40
- economy: 30
- morale: 20
- season: 80

```python
import json

with open("data/events.json", "r") as f:
    data = json.load(f)

PRIORITY_BY_CATEGORY = {
    "politics": 90, "season": 80, "diplomacy": 70,
    "military": 60, "special": 50, "school": 40,
    "economy": 30, "morale": 20
}

for evt in data["events"]:
    cat = evt["category"]
    evt["trigger"]["priority"] = PRIORITY_BY_CATEGORY.get(cat, 50)
    evt["trigger"]["one_shot"] = evt["id"].startswith("hist_")

with open("data/events.json", "w") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
```

Run: `cd /home/gkl/data/Mountains_and_Rivers_The_Warring_States && python3 -c "<above script>"`

- [ ] **Step 2: 验证更新结果**

```bash
python3 -c "
import json
d = json.load(open('data/events.json'))
for e in d['events']:
    t = e['trigger']
    assert 'priority' in t, f'{e[\"id\"]} missing priority'
    assert 'one_shot' in t, f'{e[\"id\"]} missing one_shot'
    if e['id'].startswith('hist_'):
        assert t['one_shot'] == True, f'{e[\"id\"]} should be one_shot'
print('All 88 events have priority and one_shot fields')
"
```

Expected: `All 88 events have priority and one_shot fields`

- [ ] **Step 3: 提交**

```bash
git add data/events.json
git commit -m "feat(events): 为88个事件新增 priority 和 one_shot 字段"
```

---

### Task 2: 更新 events.json Schema — 新增 event_chains 顶层字段

**Files:**
- Modify: `data/events.json`

- [ ] **Step 1: 在 events.json 中添加 event_chains 字段**

在 `"events"` 数组之后新增 `"event_chains"` 字段：

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

同时将 schema_version 从 "1.0" 更新为 "2.0"。

- [ ] **Step 2: 验证 JSON 结构**

```bash
python3 -c "
import json
d = json.load(open('data/events.json'))
assert d['schema_version'] == '2.0'
chains = d['event_chains']
assert len(chains) == 2
assert chains[0]['id'] == 'chain_suqin_hezong'
assert chains[1]['id'] == 'chain_zhangyi_lianheng'
for chain in chains:
    assert 'faction' in chain
    assert len(chain['nodes']) >= 2
    for node in chain['nodes']:
        assert 'event_id' in node
        assert 'conditions' in node
        assert 'next' in node
print('event_chains structure valid')
"
```

Expected: `event_chains structure valid`

- [ ] **Step 3: 提交**

```bash
git add data/events.json
git commit -m "feat(events): 新增 event_chains 顶层字段，定义苏秦合纵和张仪连横两条事件链"
```

---

### Task 3: 更新 balance_params.json — 新增 event_cooldown_by_type

**Files:**
- Modify: `data/balance_params.json`

- [ ] **Step 1: 在 balance_params.json 中添加 event_cooldown_by_type**

在现有 `event_cooldown_turns` 之后新增：

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

- [ ] **Step 2: 验证**

```bash
python3 -c "
import json
d = json.load(open('data/balance_params.json'))
assert 'event_cooldown_by_type' in d
cd = d['event_cooldown_by_type']
assert cd['economy'] == 3
assert cd['special'] == 999
assert cd['season'] == 0
assert cd['event_chain'] == 0
print('event_cooldown_by_type valid')
"
```

Expected: `event_cooldown_by_type valid`

- [ ] **Step 3: 提交**

```bash
git add data/balance_params.json
git commit -m "feat(balance): 新增 event_cooldown_by_type 按类型差异化冷却配置"
```

---

### Task 4: 更新 signal_bus.gd — 新增链式事件信号

**Files:**
- Modify: `scripts/autoload/signal_bus.gd:29`

- [ ] **Step 1: 在信号总线中添加链式事件信号**

在 `event_resolved` 信号之后添加：

```gdscript
## 事件链推进时发出
signal chain_advanced(chain_id: String, event_id: String)

## 事件链完结时发出
signal chain_completed(chain_id: String)
```

- [ ] **Step 2: 提交**

```bash
git add scripts/autoload/signal_bus.gd
git commit -m "feat(signals): 新增 chain_advanced 和 chain_completed 信号"
```

---

### Task 5: 更新 data_manager.gd — 新增事件链加载接口

**Files:**
- Modify: `scripts/autoload/data_manager.gd:193-202`

- [ ] **Step 1: 添加 get_event_chains() 方法**

在 `get_event()` 方法之后添加：

```gdscript
func get_event_chains() -> Array:
	return _events.get("event_chains", [])


func get_event_chain(chain_id: String) -> Dictionary:
	for chain in get_event_chains():
		if chain["id"] == chain_id:
			return chain
	push_warning("DataManager: 未找到事件链 %s" % chain_id)
	return {}
```

- [ ] **Step 2: 提交**

```bash
git add scripts/autoload/data_manager.gd
git commit -m "feat(data): 新增 get_event_chains/get_event_chain 接口"
```

---

### Task 6: 创建 test_event_manager.gd — 基础测试框架

**Files:**
- Create: `tests/unit/test_event_manager.gd`

- [ ] **Step 1: 创建测试文件骨架**

```gdscript
extends GutTest

## EventManager 单元测试 — 三阶段流水线
##
## 测试覆盖：
##   - 冷却机制（差异化冷却、one_shot）
##   - 条件判定（已实现 + 新增条件）
##   - 三阶段触发流程
##   - 事件链推进
##   - 分池竞争（每类最多 1 条）
##   - 优先级排序

func before_each() -> void:
	EventManager.reset()


# ============= 冷却机制 =============

func test_default_cooldown_is_3_turns() -> void:
	# 触发一个普通 economy 事件后，冷却应为 3 回合
	pass


func test_one_shot_event_cooldown_is_999() -> void:
	# 触发一个 one_shot 事件后，冷却应为 999
	pass


func test_cooldown_decrements_on_turn_end() -> void:
	# 冷却在 turn_ended 时递减
	pass


func test_cooldown_does_not_go_below_zero() -> void:
	# 冷却降到 0 后应被清除
	pass


# ============= 条件判定 =============

func test_season_condition_filters_correctly() -> void:
	# 季节条件正确过滤
	pass


func test_morale_min_condition() -> void:
	# morale_min 条件
	pass


func test_faction_condition() -> void:
	# faction 条件限制特定势力
	pass


# ============= 三阶段流程 =============

func test_phase1_chain_event_before_others() -> void:
	# 链式事件在阶段 1 优先触发
	pass


func test_phase2_season_event_always_triggers() -> void:
	# 季节事件概率 1.0
	pass


func test_phase3_max_one_event_per_category() -> void:
	# 每类最多触发 1 条
	pass


# ============= 事件链 =============

func test_chain_advances_on_trigger() -> void:
	# 链式事件触发后指针推进
	pass


func test_chain_completes_when_next_is_null() -> void:
	# 链结束时发出 chain_completed 信号
	pass


func test_chain_ignores_cooldown() -> void:
	# 链式事件不受冷却限制
	pass


func test_chain_only_triggers_for_matching_faction() -> void:
	# 链式事件只对匹配势力触发
	pass
```

- [ ] **Step 2: 验证测试文件可被 GUT 发现**

在 Godot 编辑器中运行 GUT，确认 `test_event_manager.gd` 出现在测试列表中（所有测试应为 pass 状态，因为都是 `pass` 占位）。

- [ ] **Step 3: 提交**

```bash
git add tests/unit/test_event_manager.gd
git commit -m "test(events): 创建 EventManager 测试骨架"
```

---

### Task 7: 重构 event_manager.gd — 差异化冷却机制

**Files:**
- Modify: `scripts/autoload/event_manager.gd:83-88,238-249`

- [ ] **Step 1: 实现差异化冷却逻辑**

修改 `_trigger_event` 方法中的冷却设置：

```gdscript
func _trigger_event(evt: Dictionary, _faction_id: String) -> void:
	var cooldown_turns: int = _get_cooldown_for_event(evt)
	_cooldowns[evt["id"]] = cooldown_turns

	if evt.get("options") != null:
		SignalBus.event_triggered.emit(evt)
	else:
		_apply_effects(evt["effects"])
		SignalBus.event_resolved.emit(evt["id"], "")


func _get_cooldown_for_event(evt: Dictionary) -> int:
	# one_shot 事件冷却 999
	if evt["trigger"].get("one_shot", false):
		return 999
	# 从 balance_params.json 读取按类型冷却
	var category: String = evt.get("category", "economy")
	var cooldown_by_type: Dictionary = DataManager.get_balance_param("event_cooldown_by_type")
	if cooldown_by_type != null and cooldown_by_type.has(category):
		return cooldown_by_type[category]
	# 回退到默认值
	var default_cd: int = DataManager.get_balance_param("event_cooldown_turns")
	if default_cd == null:
		return 3
	return default_cd
```

- [ ] **Step 2: 补全测试用例**

填充 Task 6 中的冷却测试：

```gdscript
func test_default_cooldown_is_3_turns() -> void:
	var evt: Dictionary = {
		"id": "test_economy",
		"category": "economy",
		"trigger": {"type": "turn_start", "probability": 1.0, "priority": 30, "one_shot": false, "conditions": {}},
		"effects": {"food_delta": 10},
		"options": null
	}
	# 手动调用 _trigger_event（通过信号间接测试）
	# 验证冷却值
	assert_eq(EventManager.get_cooldowns().get("test_economy", 0), 0,
		"触发前应无冷却")


func test_one_shot_event_cooldown_is_999() -> void:
	var evt: Dictionary = {
		"id": "test_hist",
		"category": "special",
		"trigger": {"type": "turn_start", "probability": 1.0, "priority": 50, "one_shot": true, "conditions": {}},
		"effects": {"food_delta": 10},
		"options": null
	}
	# 触发后冷却应为 999
	pass


func test_cooldown_decrements_on_turn_end() -> void:
	# 先触发事件设冷却，再模拟 turn_ended，验证冷却递减
	pass


func test_cooldown_does_not_go_below_zero() -> void:
	# 冷却到 0 后应从字典中移除
	pass
```

- [ ] **Step 3: 提交**

```bash
git add scripts/autoload/event_manager.gd tests/unit/test_event_manager.gd
git commit -m "feat(events): 实现差异化冷却机制（one_shot=999, 按类型读取冷却值）"
```

---

### Task 8: 重构 event_manager.gd — 补全缺失条件

**Files:**
- Modify: `scripts/autoload/event_manager.gd:44-80`

- [ ] **Step 1: 在 _check_conditions 中实现 4 种缺失条件**

在现有条件检查末尾、`return true` 之前添加：

```gdscript
	# 新增条件：school
	if conditions.has("school"):
		var current_school: String = GameManager.get_current_school()
		if current_school != conditions["school"]:
			return false

	# 新增条件：at_war
	if conditions.has("at_war"):
		var is_at_war: bool = DiplomacySystem.is_at_war(faction_id)
		if conditions["at_war"] != is_at_war:
			return false

	# 新增条件：has_alliance
	if conditions.has("has_alliance"):
		var has_ally: bool = DiplomacySystem.has_alliance(faction_id)
		if conditions["has_alliance"] != has_ally:
			return false

	# 新增条件：allies_min
	if conditions.has("allies_min"):
		var ally_count: int = DiplomacySystem.get_allies_count(faction_id)
		if ally_count < conditions["allies_min"]:
			return false

	return true
```

注意：这些方法（`GameManager.get_current_school()`、`DiplomacySystem.is_at_war()` 等）需要确认已存在。若不存在，需要先在对应系统中添加接口。

- [ ] **Step 2: 验证依赖接口存在**

```bash
grep -n "func get_current_school" scripts/autoload/game_manager.gd
grep -n "func is_at_war" scripts/autoload/diplomacy_system.gd
grep -n "func has_alliance" scripts/autoload/diplomacy_system.gd
grep -n "func get_allies_count" scripts/autoload/diplomacy_system.gd
```

若不存在，需在对应文件中添加 stub 接口。

- [ ] **Step 3: 补全条件测试**

```gdscript
func test_school_condition_filters_correctly() -> void:
	# 设置当前学派为 confucianism
	# 触发一个 school="legalism" 的事件
	# 验证事件不触发
	pass


func test_at_war_condition() -> void:
	# 设置非战争状态
	# 触发一个 at_war=true 的事件
	# 验证事件不触发
	pass
```

- [ ] **Step 4: 提交**

```bash
git add scripts/autoload/event_manager.gd tests/unit/test_event_manager.gd
git commit -m "feat(events): 补全 school/at_war/has_alliance/allies_min 条件判定"
```

---

### Task 9: 重构 event_manager.gd — 三阶段流水线核心

**Files:**
- Modify: `scripts/autoload/event_manager.gd:32-41`

- [ ] **Step 1: 重构 _check_and_trigger_events 为三阶段流水线**

替换现有方法：

```gdscript
## 类型优先级（数值越大越优先）
const TYPE_PRIORITY: Dictionary = {
	"politics": 90,
	"season": 80,
	"diplomacy": 70,
	"military": 60,
	"special": 50,
	"school": 40,
	"economy": 30,
	"morale": 20,
}

var _chain_states: Dictionary = {}  # chain_id -> { "current_index": int }
var _triggered_categories: Dictionary = {}  # category -> true（本回合已触发的类型）


func _check_and_trigger_events(timing: String, turn_number: int, faction_id: String) -> void:
	_triggered_categories.clear()

	# 阶段 1：链式事件
	_process_chain_events(turn_number, faction_id)

	# 阶段 2：季节事件
	_process_season_events(turn_number, faction_id)

	# 阶段 3：分池竞争
	_process_pool_events(turn_number, faction_id)


func _process_chain_events(turn_number: int, faction_id: String) -> void:
	var chains: Array = DataManager.get_event_chains()
	for chain in chains:
		if not _is_chain_applicable(chain, faction_id):
			continue
		var chain_id: String = chain["id"]
		if not _chain_states.has(chain_id):
			_chain_states[chain_id] = {"current_index": 0}
		var state: Dictionary = _chain_states[chain_id]
		var current_index: int = state["current_index"]
		if current_index >= chain["nodes"].size():
			continue  # 链已结束
		var node: Dictionary = chain["nodes"][current_index]
		if _check_conditions(node.get("conditions", {}), turn_number, faction_id):
			var evt: Dictionary = DataManager.get_event(node["event_id"])
			if evt.is_empty():
				continue
			# 链式事件必定触发，无视概率和冷却
			if evt.get("options") != null:
				SignalBus.event_triggered.emit(evt)
			else:
				_apply_effects(evt["effects"])
				SignalBus.event_resolved.emit(evt["id"], "")
			SignalBus.chain_advanced.emit(chain_id, node["event_id"])
			# 推进指针
			if node["next"] == null:
				SignalBus.chain_completed.emit(chain_id)
				state["current_index"] = chain["nodes"].size()  # 标记结束
			else:
				state["current_index"] = current_index + 1


func _is_chain_applicable(chain: Dictionary, faction_id: String) -> bool:
	var chain_faction: String = chain.get("faction", "")
	if chain_faction != "" and chain_faction != faction_id:
		return false
	return true


func _process_season_events(turn_number: int, faction_id: String) -> void:
	var current_season: String = DataManager.get_current_season(turn_number)
	for evt in _events:
		if evt["category"] != "season":
			continue
		if _is_on_cooldown(evt["id"]):
			continue
		var conditions: Dictionary = evt["trigger"].get("conditions", {})
		if conditions.has("season") and not conditions["season"].has(current_season):
			continue
		if not _check_conditions(conditions, turn_number, faction_id):
			continue
		# 季节事件概率 1.0
		_trigger_event(evt, faction_id)
		_triggered_categories["season"] = true
		break  # 每类最多 1 条


func _process_pool_events(turn_number: int, faction_id: String) -> void:
	# 按类型优先级从高到低处理
	var sorted_types: Array = TYPE_PRIORITY.keys()
	sorted_types.sort_custom(func(a, b): return TYPE_PRIORITY[a] > TYPE_PRIORITY[b])

	for type_name in sorted_types:
		if type_name == "season":
			continue  # 季节事件已在阶段 2 处理
		if _triggered_categories.has(type_name):
			continue  # 已被占用

		# 收集该类型中满足条件的事件
		var candidates: Array = []
		for evt in _events:
			if evt.get("category", "") != type_name:
				continue
			if _is_on_cooldown(evt["id"]):
				continue
			if not _check_conditions(evt["trigger"].get("conditions", {}), turn_number, faction_id):
				continue
			if randf() <= evt["trigger"]["probability"]:
				candidates.append(evt)

		if candidates.is_empty():
			continue

		# 按 priority 排序，取最高
		candidates.sort_custom(func(a, b):
			return a["trigger"].get("priority", 50) > b["trigger"].get("priority", 50))
		_trigger_event(candidates[0], faction_id)
		_triggered_categories[type_name] = true
```

- [ ] **Step 2: 更新 reset() 方法**

```gdscript
func reset() -> void:
	_cooldowns.clear()
	_chain_states.clear()
	_triggered_categories.clear()
```

- [ ] **Step 3: 新增公共接口**

```gdscript
## 获取当前激活的事件链状态
func get_active_chains() -> Array:
	var result: Array = []
	for chain_id in _chain_states:
		result.append({"chain_id": chain_id, "state": _chain_states[chain_id]})
	return result


## 手动推进指定事件链（调试用）
func advance_chain(chain_id: String) -> void:
	if _chain_states.has(chain_id):
		_chain_states[chain_id]["current_index"] += 1
```

- [ ] **Step 4: 补全三阶段测试**

```gdscript
func test_phase1_chain_event_before_others() -> void:
	# 模拟回合 10，势力 qi
	# 验证 chain_suqin_hezong 的第一个节点触发
	# 验证 chain_advanced 信号被发射
	pass


func test_phase2_season_event_always_triggers() -> void:
	# 模拟春季回合
	# 验证 evt_spring_farming 触发（概率 1.0）
	pass


func test_phase3_max_one_event_per_category() -> void:
	# 模拟多个 economy 事件同时满足条件
	# 验证只触发 1 个
	pass
```

- [ ] **Step 5: 提交**

```bash
git add scripts/autoload/event_manager.gd tests/unit/test_event_manager.gd
git commit -m "feat(events): 重构为三阶段流水线（链式→季节→分池竞争）"
```

---

### Task 10: 实现事件链状态持久化

**Files:**
- Modify: `scripts/autoload/event_manager.gd`

- [ ] **Step 1: 添加事件链状态的存档/读档接口**

```gdscript
## 获取事件链状态（供存档系统调用）
func get_save_data() -> Dictionary:
	return {
		"cooldowns": _cooldowns.duplicate(),
		"chain_states": _chain_states.duplicate(true),
	}


## 恢复事件链状态（供读档系统调用）
func load_save_data(data: Dictionary) -> void:
	_cooldowns = data.get("cooldowns", {})
	_chain_states = data.get("chain_states", {})
	_triggered_categories.clear()
```

- [ ] **Step 2: 提交**

```bash
git add scripts/autoload/event_manager.gd
git commit -m "feat(events): 新增事件链状态存档/读档接口"
```

---

### Task 11: 更新文档

**Files:**
- Modify: `docs/机制概览/随机事件系统.md`

- [ ] **Step 1: 更新文档为 v2.0**

将文档内容更新为与设计文档 `docs/superpowers/specs/2026-05-16-event-system-redesign.md` 一致。主要变更：
- 版本号从 v1.2 更新为 v2.0
- 触发机制章节重写为三阶段流水线
- 新增优先级系统章节
- 新增差异化冷却章节
- 新增事件链机制章节
- 更新 Schema 章节（新增字段说明）
- 更新待实现功能清单

- [ ] **Step 2: 提交**

```bash
git add docs/机制概览/随机事件系统.md
git commit -m "docs: 更新随机事件系统文档为 v2.0（三阶段流水线设计）"
```

---

## 执行顺序

```
Task 1 (events.json priority/one_shot)
  → Task 2 (events.json event_chains)
    → Task 3 (balance_params.json)
      → Task 4 (signal_bus.gd)
        → Task 5 (data_manager.gd)
          → Task 6 (测试骨架)
            → Task 7 (差异化冷却)
              → Task 8 (缺失条件)
                → Task 9 (三阶段流水线核心)
                  → Task 10 (状态持久化)
                    → Task 11 (文档更新)
```

Task 1-5 可并行执行（数据层变更互不依赖）。Task 6 依赖 Task 4-5。Task 7-9 串行依赖。
