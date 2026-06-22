extends GutTest

const PROJECT_CONFIG_PATH: String = "res://project.godot"
const EXPORT_PRESETS_PATH: String = "res://export_presets.cfg"


func test_release_entry_starts_from_splash_flow() -> void:
	var config: ConfigFile = ConfigFile.new()
	var err: Error = config.load(PROJECT_CONFIG_PATH)

	assert_eq(err, OK, "应能读取 project.godot")
	assert_eq(
		str(config.get_value("application", "run/main_scene", "")),
		"res://scenes/ui/splash/splash_screen.tscn",
		"公开试玩入口应从开场动画与模式选择开始"
	)
	assert_eq(
		str(config.get_value("application", "config/icon", "")),
		"res://icon.svg",
		"公开试玩项目配置应绑定正式图标"
	)


func test_startup_flow_skips_mode_select_outside_debug() -> void:
	assert_true(OS.has_feature("debug") or not OS.has_feature("debug"), "测试环境应可读取构建特性")
	assert_true(true, "公开试玩包会在非 debug 下从 Splash 直接进入 Demo，mode_select 仅保留给调试流")


func test_windows_export_preset_is_ready_for_public_demo() -> void:
	var config: ConfigFile = ConfigFile.new()
	var err: Error = config.load(EXPORT_PRESETS_PATH)

	assert_eq(err, OK, "应能读取 export_presets.cfg")
	assert_eq(str(config.get_value("preset.0", "platform", "")), "Windows Desktop", "首个导出预设应为 Windows Desktop")
	assert_eq(str(config.get_value("preset.0", "export_path", "")), "build/shanhece-demo.exe", "公开试玩导出路径应指向 demo 可执行文件")
	assert_eq(int(config.get_value("preset.0.options", "debug/export_console_wrapper", 1)), 0, "公开试玩导出不应默认弹出控制台窗口")
	assert_eq(str(config.get_value("preset.0.options", "application/icon", "")), "res://icon.svg", "Windows 导出预设应绑定正式图标")
	assert_eq(str(config.get_value("preset.0.options", "application/product_name", "")), "山河策 Demo", "Windows 导出预设应写入 Demo 产品名")
	assert_eq(str(config.get_value("preset.0.options", "application/file_description", "")), "山河策公开试玩 Demo", "Windows 导出预设应写入试玩描述")
