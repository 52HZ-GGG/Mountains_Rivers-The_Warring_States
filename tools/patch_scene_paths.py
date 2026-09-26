# -*- coding: utf-8 -*-
"""场景层旧资源路径 -> ai_art 统一"""
import io

def patch(path, pairs):
    s = io.open(path, encoding='utf-8').read()
    for old, new in pairs:
        assert old in s, f'NOT FOUND in {path}: {old[:60]}'
        s = s.replace(old, new)
    io.open(path, 'w', encoding='utf-8').write(s)
    print(f'patched: {path}')

# 1) big_map_panel.gd：单位图候选路径 -> ai_art/units
patch(r'E:\虚拟C盘\shanhece\shanhece-clean\scenes\ui\big_map\big_map_panel.gd', [
    ('''	var out: Array[String] = [
		"res://assets/units/animations/base/unit_%s/unit_%s" % [unit_type_id, unit_type_id],
		"res://assets/units/portraits/unit_%s" % unit_type_id,
	]''',
     '''	var out: Array[String] = [
		"res://assets/ai_art/units/%s_idle" % unit_type_id,
		"res://assets/ai_art/units/%s" % unit_type_id,
	]'''),
])

# 2) faction_select.gd：势力卡片 + 君主头像
patch(r'E:\虚拟C盘\shanhece\shanhece-clean\scenes\ui\splash\faction_select.gd', [
    ('var card_path := "res://assets/ui/panels/ui_faction_card_%s.png" % fid',
     'var card_path := "res://assets/ai_art/ui/panels/faction_card_normal.png"'),
    ('var portrait_path := "res://assets/units/portraits_hires/portrait_monarch_%s_hires.png" % faction_id',
     'var portrait_path := "res://assets/ai_art/units/portraits/lord_%s.png" % faction_id'),
])

# 3) loading_screen.gd：loading 图标 -> ai_art/ui/icons
patch(r'E:\虚拟C盘\shanhece\shanhece-clean\scenes\ui\splash\loading_screen.gd', [
    ('''		"res://assets/ui/icons/ui_loading_sword.png",
		"res://assets/ui/icons/ui_loading_bow.png",
		"res://assets/ui/icons/ui_loading_shield.png",
		"res://assets/ui/icons/ui_loading_horse.png",''',
     '''		"res://assets/ai_art/ui/icons/ui_loading_sword.png",
		"res://assets/ai_art/ui/icons/ui_loading_bow.png",
		"res://assets/ai_art/ui/icons/ui_loading_shield.png",
		"res://assets/ai_art/ui/icons/ui_loading_horse.png",'''),
])

# 4) splash_screen.gd：Logo -> ai_art/ui/misc/game_logo
patch(r'E:\虚拟C盘\shanhece\shanhece-clean\scenes\ui\splash\splash_screen.gd', [
    ('var logo_path := "res://assets/ui/logo/logo.png"',
     'var logo_path := "res://assets/ai_art/ui/misc/game_logo.png"'),
])

# 5) buff_panel.gd：buff/debuff 图标 -> ai_art/ui/icons（无精确图标时回退通用图）
patch(r'E:\虚拟C盘\shanhece\shanhece-clean\scenes\ui\buff\buff_panel.gd', [
    ('''		var icon_path := "res://assets/ui/icons/icon_buff_%s.png" % icon_name
		if data.get("type", "buff") == "debuff":
			icon_path = "res://assets/ui/icons/icon_debuff_%s.png" % icon_name
		if ResourceLoader.exists(icon_path):
			btn.icon = load(icon_path)
			btn.expand_icon = true''',
     '''		var icon_path := "res://assets/ai_art/ui/icons/icon_buff_%s.png" % icon_name
		if data.get("type", "buff") == "debuff":
			icon_path = "res://assets/ai_art/ui/icons/icon_debuff_%s.png" % icon_name
		if not ResourceLoader.exists(icon_path):
			# 无精确图标时回退通用图标
			var generic := "res://assets/ai_art/ui/icons/icon_buff_generic.png" if data.get("type", "buff") != "debuff" else "res://assets/ai_art/ui/icons/icon_debuff_generic.png"
			if ResourceLoader.exists(generic):
				icon_path = generic
		if ResourceLoader.exists(icon_path):
			btn.icon = load(icon_path)
			btn.expand_icon = true'''),
])

print('all scene paths patched')
