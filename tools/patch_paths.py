# -*- coding: utf-8 -*-
import io

p = r'E:\虚拟C盘\shanhece\shanhece-clean\scripts\ui\skirmish_tile_textures.gd'
s = io.open(p, encoding='utf-8').read()

old_building = '''		match category:
			"economy":
				path = "res://assets/buildings/tile_building_economy.png"
			"military":
				path = "res://assets/buildings/tile_building_military.png"
			"defense":
				path = "res://assets/buildings/tile_building_defense.png"
			"politics":
				path = "res://assets/buildings/tile_building_politics.png"
			_:
				path = "res://assets/buildings/tile_building_economy.png"'''
new_building = '''		match category:
			"economy":
				path = "res://assets/ai_art/map_buildings/map_market.png"
			"military":
				path = "res://assets/ai_art/map_buildings/map_barracks.png"
			"defense":
				path = "res://assets/ai_art/map_buildings/map_wall.png"
			"politics":
				path = "res://assets/ai_art/map_buildings/map_academy.png"
			_:
				path = "res://assets/ai_art/map_buildings/map_market.png"'''
assert old_building in s, 'building block not found'
s = s.replace(old_building, new_building)

old_icon = 'const _ICON_BASE_PATH: String = "res://assets/ui/icons/"'
new_icon = 'const _ICON_BASE_PATH: String = "res://assets/ai_art/ui/icons/"'
assert old_icon in s, 'icon base not found'
s = s.replace(old_icon, new_icon)

io.open(p, 'w', encoding='utf-8').write(s)
print('patched ok')
