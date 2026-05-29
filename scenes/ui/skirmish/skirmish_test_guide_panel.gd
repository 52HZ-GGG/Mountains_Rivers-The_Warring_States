extends CanvasLayer

## 战术演武 — 游戏内测试指南面板
## 根据 scenario_id 显示对应场景的测试操作说明

@onready var _title: Label = %Title
@onready var _close_btn: Button = %CloseBtn
@onready var _content: RichTextLabel = %GuideContent

var _current_scenario_id: String = ""


func _ready() -> void:
	visible = false
	SkirmishTileTextures.style_scene_button(_close_btn)
	_close_btn.pressed.connect(_on_close_pressed)


## 打开面板并显示指定场景的测试指南
func open_guide(scenario_id: String) -> void:
	_current_scenario_id = scenario_id
	_update_content()
	show()


func _on_close_pressed() -> void:
	hide()


func _update_content() -> void:
	var data: Dictionary = _get_guide_data(_current_scenario_id)
	_title.text = str(data.get("title", "测试指南"))
	_content.text = str(data.get("body", "暂无指南。"))
	_content.scroll_to_line(0)


func _get_guide_data(scenario_id: String) -> Dictionary:
	var all: Dictionary = {
		"basic_plains": {
			"title": "测试指南 — 基础平原战",
			"body": _guide_basic_plains(),
		},
		"ranged_warfare": {
			"title": "测试指南 — 弓弩射程战",
			"body": _guide_ranged_warfare(),
		},
		"naval_battle": {
			"title": "测试指南 — 水战演兵",
			"body": _guide_naval_battle(),
		},
		"siege_warfare": {
			"title": "测试指南 — 攻城战",
			"body": _guide_siege_warfare(),
		},
		"supply_warfare": {
			"title": "测试指南 — 补给线战",
			"body": _guide_supply_warfare(),
		},
		"winter_naval": {
			"title": "测试指南 — 冬季水战",
			"body": _guide_winter_naval(),
		},
		"fire_attack": {
			"title": "测试指南 — 火攻演兵",
			"body": _guide_fire_attack(),
		},
	}
	if all.has(scenario_id):
		return all[scenario_id]
	return {"title": "测试指南", "body": "暂无此场景的测试指南。"}


# ============================================================
#  场景 1：基础平原战
# ============================================================
func _guide_basic_plains() -> String:
	return """[b][color=yellow]地图[/color][/b] 7x7 ｜ [b][color=yellow]季节[/color][/b] 任意 ｜
[b][color=yellow]我方[/color][/b] 秦（2步兵+1骑兵） ｜ [b][color=yellow]敌方[/color][/b] 赵（2步兵+1骑兵）

[b][color=cyan]1.1 基本战斗[/color][/b]
① 选中 bp_p1（步兵，1,3），向敌方 bp_e1（步兵，5,3）方向移动
② 移动到攻击范围后（距离≤1），点击 bp_e1 发起攻击
③ 观察日志中的伤害数值
[indent][color=gray]预期：伤害根据 atk×morale/(def×terrain_def) 公式计算，森林防御约+20%[/color][/indent]

[b][color=cyan]1.2 地形修正[/color][/b]
① 将 bp_p1 移到 (3,3) 的 [b]山地[/b] 格（地图中央）
② 让敌方步兵攻击你
③ 对比在平原格被攻击的伤害
[indent][color=gray]预期：山地防御加成高（约+40%），受到的伤害明显低于平原[/color][/indent]

[b][color=cyan]1.3 ZoC 区域控制[/color][/b]
① 将 bp_p1（步兵）移到 (3,2)，bp_p2（步兵）移到 (3,4)
② 敌方 bp_e1 在 (5,3)，观察敌方穿过 ZoC 区域时是否消耗额外行动力
[indent][color=gray]预期：步兵产生 ZoC，敌方经过时额外消耗1移动力。骑兵免疫 ZoC[/color][/indent]

[b][color=cyan]1.4 士气系统[/color][/b]
① 持续攻击同一敌方单位，观察士气值下降
② 击杀后，观察击杀者士气+15，其他友军+5
③ 让敌方击杀我方单位，观察敌方全体+5，我方全体-5
[indent][color=gray]预期：士气低于20时进入崩溃态，自动向友方城市溃退[/color][/indent]"""


# ============================================================
#  场景 2：弓弩射程战
# ============================================================
func _guide_ranged_warfare() -> String:
	return """[b][color=yellow]地图[/color][/b] 9x7 ｜ [b][color=yellow]季节[/color][/b] 任意 ｜
[b][color=yellow]我方[/color][/b] 秦（1弓兵+1弩兵+2步兵） ｜ [b][color=yellow]敌方[/color][/b] 赵（同配置）

[b][color=cyan]2.1 远程遮挡（高程差）[/color][/b]
① 将 rw_p1（弓兵，1,3）移动到 (4,0) 的 [b]山地[/b] 格
② 从山地射击平原上的敌方，再移到平原射击同一目标
③ 对比两次伤害
[indent][color=gray]预期：从高处射低处不受削减；从低射高每高1级射程-1[/color][/indent]

[b][color=cyan]2.2 克制矩阵[/color][/b]
① 用 rw_p2（弩兵）攻击敌方步兵 rw_e3
② 用 rw_p1（弓兵）攻击同一敌方步兵
③ 对比伤害差异
[indent][color=gray]预期：弩兵对步兵有克制加成（伤害>1.0倍），弓兵对骑兵有克制[/color][/indent]

[b][color=cyan]2.3 射程计算[/color][/b]
① 选中弓兵，查看可攻击范围（射程=2格）
② 选中弩兵，查看可攻击范围（射程=3格）
③ 步兵射程=1格
[indent][color=gray]预期：高亮显示射程内敌方，超出射程不可选中[/color][/indent]

[b][color=cyan]2.4 沼泽地形[/color][/b]
① 将任意单位移动经过 (3,2) 或 (5,2) 的沼泽格
[indent][color=gray]预期：沼泽移动消耗高于平原（通常2点），防御加成低或为负[/color][/indent]"""


# ============================================================
#  场景 3：水战演兵
# ============================================================
func _guide_naval_battle() -> String:
	return """[b][color=yellow]地图[/color][/b] 9x7 ｜ [b][color=yellow]季节[/color][/b] 夏季 ｜
[b][color=yellow]我方[/color][/b] 秦（1步兵+1骑兵+1艨冲+1大翼） ｜ [b][color=yellow]敌方[/color][/b] 楚（1步兵+1骑兵+1艨冲+1楼船）

[b][color=cyan]3.1 海军战斗修正[/color][/b]
① 将 nb_p3（艨冲）移动到河流格 (4,1) 或 (4,2)
② 用艨冲攻击敌方 nb_e3（敌方艨冲，河流格5,2）
③ 再用 nb_p1（步兵）从陆地攻击同一敌方艨冲
④ 对比两次伤害
[indent][color=gray]预期：水军在河流有战斗加成；陆军打水军伤害被削减（海军防御修正）[/color][/indent]

[b][color=cyan]3.2 水面移动[/color][/b]
① 选中 nb_p3（艨冲），观察河流格上的移动范围
② 选中 nb_p1（步兵），观察河流格上的移动范围
[indent][color=gray]预期：水军在河流移动消耗低；陆军在河流消耗高或不可通行[/color][/indent]

[b][color=cyan]3.3 渡口通行[/color][/b]
① 将 nb_p1（步兵）移动到 (3,3) 的 [b]渡口[/b] 格
② 从渡口跨河移动到 (4,3) 的河流格
[indent][color=gray]预期：渡口是陆军跨河的唯一通道[/color][/indent]

[b][color=cyan]3.4 水军 vs 陆军[/color][/b]
① 将 nb_p3（艨冲）移动到陆地格（如2,2森林）
② 用陆地上的艨冲攻击敌方步兵
[indent][color=gray]预期：水军在陆地战斗力大幅下降（搁浅修正，攻击力×0.3）[/color][/indent]"""


# ============================================================
#  场景 4：攻城战
# ============================================================
func _guide_siege_warfare() -> String:
	return """[b][color=yellow]地图[/color][/b] 9x9 ｜ [b][color=yellow]季节[/color][/b] 夏季 ｜
[b][color=yellow]我方[/color][/b] 秦（2步兵+1冲车+1投石+1弓兵） ｜ [b][color=yellow]敌方[/color][/b] 赵（2步兵+1弩兵，守城）

[b][color=cyan]4.1 城墙HP与伤害分流[/color][/b]
① 将 sw_p1（步兵）移动到敌方城格 (8,4) 的相邻格
② 用步兵攻击守城敌军 sw_e1
③ 观察日志：伤害分流——一部分打城墙，一部分打单位
[indent][color=gray]预期：伤害按比例分流（默认50%城墙+50%单位），城墙HP归零后全打单位[/color][/indent]

[b][color=cyan]4.2 攻城器械倍率[/color][/b]
① 将 sw_p3（冲车）移动到敌方城格附近
② 用冲车攻击城格，再用普通步兵攻击城格
③ 对比两次对城墙的伤害
[indent][color=gray]预期：攻城器械对城墙伤害×3（siege_damage_multiplier）[/color][/indent]

[b][color=cyan]4.3 箭塔攻击[/color][/b]
① 将我方单位移动到敌方城格的相邻格（不攻击，仅站位）
② 结束回合，观察敌方回合时箭塔是否自动攻击
[indent][color=gray]预期：高级城池（level≥3）有箭塔，敌方回合自动攻击相邻攻城方[/color][/indent]

[b][color=cyan]4.4 关隘通行[/color][/b]
① 地图 (4,2) 和 (4,6) 有两个关隘格
② 将步兵移动到关隘格，从关隘格发起攻击
[indent][color=gray]预期：关隘有独立HP和防御加成，结构会吸收部分伤害[/color][/indent]

[b][color=cyan]4.5 占领判定[/color][/b]
① 消灭敌方城格 (8,4) 上的所有敌军
② 将我方单位移动到城格上
[indent][color=gray]预期：敌方城池无敌军且我方站上去→占领→胜利[/color][/indent]"""


# ============================================================
#  场景 5：补给线战
# ============================================================
func _guide_supply_warfare() -> String:
	return """[b][color=yellow]地图[/color][/b] 9x7 ｜ [b][color=yellow]季节[/color][/b] 夏季 ｜
[b][color=yellow]我方[/color][/b] 秦（2步兵+1骑兵+1弓兵） ｜ [b][color=yellow]敌方[/color][/b] 赵（2步兵+2骑兵）

[b][color=cyan]5.1 断粮 BFS[/color][/b]
① 将 sp_p1（步兵，1,3）向地图中央沙漠区域推进
② 深入沙漠后，悬停该单位，观察状态是否显示"断粮"
③ 对比留在后方的 sp_p2（步兵，0,2），悬停查看是否"已补给"
[indent][color=gray]预期：BFS检查从单位到友方城市的连通性，沙漠/沼泽阻隔→断粮[/color][/indent]

[b][color=cyan]5.2 士气崩溃[/color][/b]
① 让断粮单位每回合士气持续下降
② 同时让敌方攻击该断粮单位，加速士气下降
③ 观察士气降到20以下时的状态变化
[indent][color=gray]预期：士气低于阈值→崩溃态，无法被玩家控制，自动溃退[/color][/indent]

[b][color=cyan]5.3 溃退与追击[/color][/b]
① 让一个我方单位士气崩溃
② 观察该单位是否自动向我方城市 (0,3) 方向移动
③ 如果溃退路径上有敌方步兵/骑兵，观察是否触发追击
[indent][color=gray]预期：崩溃态自动溃退；经过敌方ZoC时触发追击；被包围无法溃退[/color][/indent]

[b][color=cyan]5.4 治疗回复[/color][/b]
① 让一个受伤单位撤退到我方城格 (0,3) 上
② 结束几个回合，观察HP是否恢复
[indent][color=gray]预期：友方城池上的单位每回合回复HP[/color][/indent]"""


# ============================================================
#  场景 6：冬季水战
# ============================================================
func _guide_winter_naval() -> String:
	return """[b][color=yellow]地图[/color][/b] 9x7 ｜ [b][color=yellow]季节[/color][/b] 冬季 ｜
[b][color=yellow]我方[/color][/b] 秦（1步兵+1骑兵+1艨冲+1大翼） ｜ [b][color=yellow]敌方[/color][/b] 楚（同配置）

[b][color=cyan]6.1 河流冻结[/color][/b]
① 开始演武时选择 [b]冬季[/b]
② 观察河流格 (4,0)-(4,6) 的视觉状态是否与夏季不同
③ 将步兵 wn_p1 尝试移动到河流格
[indent][color=gray]预期：冬季河流冻结，变为可通行地形，陆军可正常通过[/color][/indent]

[b][color=cyan]6.2 搁浅状态[/color][/b]
① 将 wn_p3（艨冲）移动到冻结的河流格上
② 悬停查看单位状态
[indent][color=gray]预期：水军在冻结河流上搁浅——攻击力×0.3，无法主动攻击[/color][/indent]

[b][color=cyan]6.3 搁浅攻击限制[/color][/b]
① 确认 wn_p3（艨冲）处于搁浅状态
② 尝试选中该单位并点击敌方单位发起攻击
[indent][color=gray]预期：搁浅单位无法发起主动攻击，只能被动挨打[/color][/indent]

[b][color=cyan]6.4 冬季火攻禁用[/color][/b]
① 将 wn_p1（步兵）移动到森林格
② 让敌方步兵在森林格上攻击我方
[indent][color=gray]预期：冬季不触发火攻，即使目标在森林格也不会被点燃[/color][/indent]"""


# ============================================================
#  场景 7：火攻演兵
# ============================================================
func _guide_fire_attack() -> String:
	return """[b][color=yellow]地图[/color][/b] 7x7 ｜ [b][color=yellow]季节[/color][/b] 夏季 ｜
[b][color=yellow]我方[/color][/b] 秦（3步兵+1弓兵） ｜ [b][color=yellow]敌方[/color][/b] 赵（3步兵+1骑兵）

[b][color=cyan]7.1 火攻触发[/color][/b]
① 将 fa_p1（步兵，1,3）移动到敌方 fa_e1（步兵，5,3）附近的森林格
② 确保敌方在森林格上（如 4,2 或 3,3 的森林）
③ 从我方单位攻击森林格上的敌方单位
④ 观察日志中是否出现"被点燃"提示
[indent][color=gray]预期：夏季+目标在森林→触发火攻，额外+40%伤害，目标被施加烧伤DOT[/color][/indent]

[b][color=cyan]7.2 烧伤 DOT[/color][/b]
① 用上述方法点燃一个敌方单位
② 结束当前回合，观察敌方回合开始时烧伤伤害
③ 再结束一个回合，观察烧伤是否持续（默认2回合）
[indent][color=gray]预期：burn_turns=2，每回合自动扣减，烧伤致死触发友军士气下降[/color][/indent]

[b][color=cyan]7.3 夹击[/color][/b]
① 将 fa_p1 移到敌方 fa_e1 的一侧（如 4,3）
② 将 fa_p4 移到 fa_e1 的[b]对面[/b]侧（如 6,3）
③ 用其中一个攻击 fa_e1
[indent][color=gray]预期：对面两方向（180°）都有敌方→夹击，被夹击方士气-20[/color][/indent]

[b][color=cyan]7.4 包围[/color][/b]
① 用3步兵+1弓兵占据敌方单位的全部6个相邻格
② 攻击该单位
[indent][color=gray]预期：6格全敌→包围，士气-50，溃退时额外损失HP无法逃走[/color][/indent]

[b][color=cyan]7.5 伏击判定[/color][/b]
① 将我方步兵移动到森林格
② 从森林格攻击敌方单位，多次重复
[indent][color=gray]预期：伏击概率触发（基础5%+森林加成），触发时伤害+30%[/color][/indent]

[b][color=cyan]7.6 季节限制验证[/color][/b]
① 退出当前演武，重新选择"火攻演兵"，季节选择 [b]冬季[/b]
② 尝试在森林格上攻击敌方
[indent][color=gray]预期：冬季不会触发火攻，即使目标在森林格也不会被点燃[/color][/indent]"""
