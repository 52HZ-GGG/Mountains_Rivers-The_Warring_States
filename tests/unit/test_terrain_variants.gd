extends GutTest


const EXPECTED_COUNTS: Dictionary = {
	"plains": 3, "forest": 3, "mountain": 3, "marsh": 3,
	"desert": 3, "tundra": 3, "pass": 2,
	"shallow_ocean": 2, "deep_ocean": 2,
}


func test_all_terrain_variants_load() -> void:
	for terrain_id: String in EXPECTED_COUNTS:
		var count: int = int(EXPECTED_COUNTS[terrain_id])
		assert_eq(SkirmishTileTextures.terrain_variant_count(terrain_id), count)
		for index: int in range(count):
			var path: String = SkirmishTileTextures.terrain_variant_path(terrain_id, index)
			assert_true(ResourceLoader.exists(path), path)
			assert_not_null(SkirmishTileTextures.terrain_texture_by_variant(terrain_id, index), path)


func test_variant_selection_is_stable_and_uses_every_style() -> void:
	for terrain_id: String in EXPECTED_COUNTS:
		var seen: Dictionary = {}
		for row: int in range(12):
			for col: int in range(12):
				var index: int = SkirmishTileTextures.terrain_variant_index(terrain_id, col, row)
				assert_eq(index, SkirmishTileTextures.terrain_variant_index(terrain_id, col, row))
				seen[index] = true
		assert_eq(seen.size(), int(EXPECTED_COUNTS[terrain_id]), terrain_id)


func test_edge_blends_respect_coast_and_deep_water() -> void:
	assert_eq(SkirmishTileTextures.terrain_edge_blend_alpha("plains", "forest"), 0.5)
	assert_eq(SkirmishTileTextures.terrain_edge_blend_alpha("marsh", "desert"), 0.5)
	assert_eq(SkirmishTileTextures.terrain_edge_blend_alpha("shallow_ocean", "deep_ocean"), 0.5)
	assert_eq(SkirmishTileTextures.terrain_edge_blend_alpha("plains", "shallow_ocean"), 0.25)
	assert_eq(SkirmishTileTextures.terrain_edge_blend_alpha("deep_ocean", "plains"), 0.0)
	assert_eq(SkirmishTileTextures.terrain_edge_blend_alpha("plains", "plains"), 0.0)
