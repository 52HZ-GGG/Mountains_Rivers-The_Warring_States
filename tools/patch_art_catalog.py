# -*- coding: utf-8 -*-
import io

p = r'E:\虚拟C盘\shanhece\shanhece-clean\scripts\ui\art_catalog.gd'
s = io.open(p, encoding='utf-8').read()

# 1) 城市回退 -> ai_art/cities
old = 'var engine_tex := _load_tex("res://assets/tiles/" + fname)'
new = 'var engine_tex := _load_tex("res://assets/ai_art/cities/" + fname)'
assert old in s, 'cities fallback not found'
s = s.replace(old, new)

# 2) 地形回退 -> ai_art/terrain
old = 'return _load_tex("res://assets/terrain/" + fname)'
new = 'return _load_tex("res://assets/ai_art/terrain/" + fname)'
assert old in s, 'terrain fallback not found'
s = s.replace(old, new)

# 3) 图标回退 -> ai_art/ui/icons
old = 'return _load_tex("res://assets/ui/icons/" + str(old_map[icon_key]))'
new = 'return _load_tex("res://assets/ai_art/ui/icons/" + str(old_map[icon_key]))'
assert old in s, 'icon fallback not found'
s = s.replace(old, new)

# 4) 高亮回退 -> ai_art/ui/highlights（文件名对齐 ai_art 命名）
old = '''	var old := {
		"selected": "ui_highlight_select.png",
		"move": "ui_highlight_move.png",
		"attack": "ui_highlight_attack.png",
	}
	return _load_tex("res://assets/ui/highlights/" + str(old.get(kind, "ui_highlight_select.png")))'''
new = '''	var old := {
		"selected": "highlight_selected.png",
		"move": "highlight_move.png",
		"attack": "highlight_attack.png",
	}
	return _load_tex("res://assets/ai_art/ui/highlights/" + str(old.get(kind, "highlight_selected.png")))'''
assert old in s, 'highlight fallback not found'
s = s.replace(old, new)

# 5) 事件回退 -> ai_art/events
old = 'return _load_tex("res://assets/events/" + fname)'
new = 'return _load_tex("res://assets/ai_art/events/" + fname)'
assert old in s, 'event fallback not found'
s = s.replace(old, new)

io.open(p, 'w', encoding='utf-8').write(s)
print('art_catalog patched ok')
