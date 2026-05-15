extends CanvasLayer
## 主菜单界面
## 负责：标题显示 / 按钮动画 / 场景切换 / 设置面板控制


# ============================================================
# 节点引用（@onready）
# ============================================================

@onready var _title_label: Label = $TitleContainer/TitleLabel
@onready var _version_label: Label = $VersionLabel
@onready var _start_btn: Button = $MenuContainer/VBoxContainer/StartButton
@onready var _settings_btn: Button = $MenuContainer/VBoxContainer/SettingsButton
@onready var _quit_btn: Button = $MenuContainer/VBoxContainer/QuitButton
@onready var _settings_panel: Panel = $SettingsPanel
@onready var _dim_overlay: ColorRect = $DimOverlay


# ============================================================
# 常量
# ============================================================

const GAME_SCENE_PATH: String = "res://scenes/main/MainScene.tscn"
const GAME_VERSION: String = "v0.1.0"


# ============================================================
# 生命周期函数
# ============================================================

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# 连接按钮信号
	_start_btn.pressed.connect(_on_start_pressed)
	_settings_btn.pressed.connect(_on_settings_pressed)
	_quit_btn.pressed.connect(_on_quit_pressed)

	# 连接设置面板内部按钮
	var close_btn: Button = _settings_panel.get_node_or_null("VBoxContainer/CloseButton")
	if close_btn:
		close_btn.pressed.connect(_on_settings_close)

	# 应用样式
	_apply_panel_style()
	_apply_button_styles()
	_setup_settings_panel()

	# 设置版本号
	_version_label.text = GAME_VERSION

	# 入场淡入动画
	_play_enter_animation()

	print("[MainMenu] 主菜单就绪")


# ============================================================
# 入场动画
# ============================================================

func _play_enter_animation() -> void:
	## 标题和按钮依次淡入
	_title_label.modulate.a = 0.0
	var menu_panel: Panel = $MenuContainer
	menu_panel.modulate.a = 0.0

	var tween := create_tween()
	tween.tween_property(_title_label, "modulate:a", 1.0, 0.6).set_ease(Tween.EASE_OUT)
	tween.tween_property(menu_panel, "modulate:a", 1.0, 0.4)
	tween.tween_property(_version_label, "modulate:a", 1.0, 0.3)


# ============================================================
# 面板样式
# ============================================================

func _apply_panel_style() -> void:
	## 设置主菜单面板的暗黑风格
	var menu_style := StyleBoxFlat.new()
	menu_style.bg_color = Color(0.05, 0.05, 0.08, 0.7)
	menu_style.border_width_left = 1
	menu_style.border_width_right = 1
	menu_style.border_width_top = 1
	menu_style.border_width_bottom = 1
	menu_style.border_color = Color(0.3, 0.3, 0.35, 0.5)
	menu_style.corner_radius_top_left = 8
	menu_style.corner_radius_top_right = 8
	menu_style.corner_radius_bottom_left = 8
	menu_style.corner_radius_bottom_right = 8
	$MenuContainer.add_theme_stylebox_override("panel", menu_style)

	# 设置面板样式
	var settings_style := StyleBoxFlat.new()
	settings_style.bg_color = Color(0.06, 0.06, 0.09, 0.95)
	settings_style.border_width_left = 2
	settings_style.border_width_right = 2
	settings_style.border_width_top = 2
	settings_style.border_width_bottom = 2
	settings_style.border_color = Color(0.5, 0.45, 0.3, 0.6)
	settings_style.corner_radius_top_left = 10
	settings_style.corner_radius_top_right = 10
	settings_style.corner_radius_bottom_left = 10
	settings_style.corner_radius_bottom_right = 10
	_settings_panel.add_theme_stylebox_override("panel", settings_style)


func _apply_button_styles() -> void:
	## 统一按钮暗黑风格 + 金色悬停
	var buttons: Array[Button] = [_start_btn, _settings_btn, _quit_btn]
	for btn in buttons:
		# 普通
		var normal := StyleBoxFlat.new()
		normal.bg_color = Color(0.1, 0.1, 0.12, 0.9)
		normal.border_width_left = 2
		normal.border_width_right = 2
		normal.border_width_top = 2
		normal.border_width_bottom = 2
		normal.border_color = Color(0.35, 0.35, 0.4, 0.7)
		normal.corner_radius_top_left = 6
		normal.corner_radius_top_right = 6
		normal.corner_radius_bottom_left = 6
		normal.corner_radius_bottom_right = 6
		normal.content_margin_left = 20
		normal.content_margin_right = 20
		btn.add_theme_stylebox_override("normal", normal)

		# 悬停 — 金色发光
		var hover := StyleBoxFlat.new()
		hover.bg_color = Color(0.2, 0.18, 0.08, 0.95)
		hover.border_width_left = 2
		hover.border_width_right = 2
		hover.border_width_top = 2
		hover.border_width_bottom = 2
		hover.border_color = Color(1.0, 0.75, 0.2, 0.9)
		hover.corner_radius_top_left = 6
		hover.corner_radius_top_right = 6
		hover.corner_radius_bottom_left = 6
		hover.corner_radius_bottom_right = 6
		hover.content_margin_left = 20
		hover.content_margin_right = 20
		hover.shadow_size = 8
		hover.shadow_color = Color(1.0, 0.6, 0.1, 0.3)
		btn.add_theme_stylebox_override("hover", hover)

		# 按下
		var pressed := StyleBoxFlat.new()
		pressed.bg_color = Color(0.06, 0.06, 0.08, 0.95)
		pressed.border_width_left = 2
		pressed.border_width_right = 2
		pressed.border_width_top = 2
		pressed.border_width_bottom = 2
		pressed.border_color = Color(0.7, 0.55, 0.15, 0.8)
		pressed.corner_radius_top_left = 6
		pressed.corner_radius_top_right = 6
		pressed.corner_radius_bottom_left = 6
		pressed.corner_radius_bottom_right = 6
		pressed.content_margin_left = 20
		pressed.content_margin_right = 20
		btn.add_theme_stylebox_override("pressed", pressed)

		btn.add_theme_color_override("font_color", Color(0.85, 0.85, 0.8, 1.0))
		btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.7, 1.0))
		btn.add_theme_font_size_override("font_size", 18)


# ============================================================
# 设置面板
# ============================================================

func _setup_settings_panel() -> void:
	## 初始化音量滑块和全屏复选框
	var vol_slider: HSlider = _settings_panel.get_node_or_null("VBoxContainer/VolumeSlider")
	if vol_slider:
		vol_slider.value_changed.connect(_on_volume_changed)
		# 从 AudioManager 读取当前音量
		vol_slider.value = AudioManager.get_master_volume()

	var fullscreen_cb: CheckBox = _settings_panel.get_node_or_null("VBoxContainer/FullscreenCheck")
	if fullscreen_cb:
		fullscreen_cb.toggled.connect(_on_fullscreen_toggled)
		fullscreen_cb.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN

	_settings_panel.hide()


func _on_volume_changed(value: float) -> void:
	## 音量滑块变化
	AudioManager.set_master_volume(value)


func _on_fullscreen_toggled(enabled: bool) -> void:
	## 全屏切换
	if enabled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func _on_settings_close() -> void:
	## 关闭设置面板 → 返回主菜单
	_settings_panel.hide()
	_dim_overlay.hide()
	$MenuContainer.show()


# ============================================================
# 按钮回调
# ============================================================

func _on_start_pressed() -> void:
	## 开始游戏 → 淡出 → 切换场景
	print("[MainMenu] 开始游戏")
	# 整体淡出：用一个黑色 ColorRect 覆盖
	var fade := ColorRect.new()
	fade.name = "FadeOverlay"
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fade)
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, 0.4)
	tween.tween_callback(_switch_to_game)


func _switch_to_game() -> void:
	## 切换到游戏场景
	get_tree().change_scene_to_file(GAME_SCENE_PATH)


func _on_settings_pressed() -> void:
	## 打开设置面板
	$MenuContainer.hide()
	_dim_overlay.show()
	_settings_panel.show()

	# 面板弹入动画
	_settings_panel.scale = Vector2(0.9, 0.9)
	var tween := create_tween()
	tween.tween_property(_settings_panel, "scale", Vector2(1.0, 1.0), 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _on_quit_pressed() -> void:
	## 退出游戏
	print("[MainMenu] 退出游戏")
	get_tree().quit()
