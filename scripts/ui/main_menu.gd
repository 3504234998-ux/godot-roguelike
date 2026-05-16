extends CanvasLayer
## 主菜单界面
## 负责：标题显示 / 按钮动画 / 场景切换 / 设置面板控制 / 存档检测


# ============================================================
# 节点引用（@onready）
# ============================================================

@onready var _title_label: Label = $TitleContainer/TitleLabel
@onready var _version_label: Label = $VersionLabel
@onready var _menu_container: Panel = $MenuContainer
@onready var _vbox: VBoxContainer = $MenuContainer/VBoxContainer
@onready var _start_btn: Button = $MenuContainer/VBoxContainer/StartButton
@onready var _settings_btn: Button = $MenuContainer/VBoxContainer/SettingsButton
@onready var _quit_btn: Button = $MenuContainer/VBoxContainer/QuitButton
@onready var _settings_panel: Panel = $SettingsPanel
@onready var _dim_overlay: ColorRect = $DimOverlay

## 继续游戏按钮（动态创建）
var _continue_btn: Button = null


# ============================================================
# 常量
# ============================================================

const GAME_SCENE_PATH: String = "res://scenes/main/MainScene.tscn"
const GAME_VERSION: String = "v0.2.0"


# ============================================================
# 生命周期函数
# ============================================================

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# 创建"继续游戏"按钮（插入到 VBoxContainer 最顶部）
	_create_continue_button()

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
	_adjust_panel_size()
	_setup_settings_panel()

	# 设置版本号
	_version_label.text = GAME_VERSION

	# 入场淡入动画
	_play_enter_animation()

	print("[MainMenu] 主菜单就绪 — 存档状态: %s" % ("存在" if SaveManager.has_save(0) else "无"))


# ============================================================
# 继续游戏按钮（动态创建）
# ============================================================

func _create_continue_button() -> void:
	## 在 VBoxContainer 顶部插入"继续游戏"按钮
	_continue_btn = Button.new()
	_continue_btn.name = "ContinueButton"
	_continue_btn.text = "继续游戏"
	_continue_btn.custom_minimum_size = Vector2(200, 36)

	# 检查是否有存档
	if not SaveManager.has_save(0):
		_continue_btn.disabled = true
		_continue_btn.tooltip_text = "没有可用的存档"
	else:
		_continue_btn.tooltip_text = _build_slot_tooltip()

	_continue_btn.pressed.connect(_on_continue_pressed)

	# 插入到第一个位置（在最上方）
	_vbox.add_child(_continue_btn)
	_vbox.move_child(_continue_btn, 0)


func _build_slot_tooltip() -> String:
	## 构建槽位信息提示文本
	var info: Dictionary = SaveManager.get_slot_info(0)
	if not info.get("has_save", false):
		return "没有可用的存档"

	var minutes: int = int(info.get("play_time", 0.0)) / 60
	var seconds: int = int(info.get("play_time", 0.0)) % 60
	return "等级 %d | 波次 %d | %d分%02d秒" % [info.get("level", 1), info.get("wave", 1), minutes, seconds]


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
	## 统一按钮暗黑风格 + 金色悬停（包括动态创建的继续按钮）
	var buttons: Array[Button] = [_continue_btn, _start_btn, _settings_btn, _quit_btn]
	for btn in buttons:
		if not btn:
			continue
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

		# 禁用状态（灰色）
		var disabled := StyleBoxFlat.new()
		disabled.bg_color = Color(0.08, 0.08, 0.1, 0.7)
		disabled.border_width_left = 2
		disabled.border_width_right = 2
		disabled.border_width_top = 2
		disabled.border_width_bottom = 2
		disabled.border_color = Color(0.2, 0.2, 0.25, 0.4)
		disabled.corner_radius_top_left = 6
		disabled.corner_radius_top_right = 6
		disabled.corner_radius_bottom_left = 6
		disabled.corner_radius_bottom_right = 6
		disabled.content_margin_left = 20
		disabled.content_margin_right = 20
		btn.add_theme_stylebox_override("disabled", disabled)

		btn.add_theme_color_override("font_color", Color(0.85, 0.85, 0.8, 1.0))
		btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.7, 1.0))
		btn.add_theme_color_override("font_disabled_color", Color(0.4, 0.4, 0.4, 0.6))
		btn.add_theme_font_size_override("font_size", 16)

	# 缩小 VBoxContainer 按钮间距，避免 4 个按钮超出面板
	_vbox.add_theme_constant_override("separation", 6)


func _adjust_panel_size() -> void:
	## 根据按钮数量动态调整面板最小高度，防止溢出背景框
	# 统一所有按钮高度（包括 .tscn 中原有的按钮）
	for btn in [_continue_btn, _start_btn, _settings_btn, _quit_btn]:
		if btn:
			btn.custom_minimum_size = Vector2(200, 36)

	var btn_count: int = _vbox.get_child_count()
	var btn_height: float = 36.0
	var separation: float = 6.0
	var padding: float = 36.0
	var total_h: float = btn_count * btn_height + (btn_count - 1) * separation + padding
	_menu_container.custom_minimum_size = Vector2(260, total_h)


# ============================================================
# 设置面板
# ============================================================

func _setup_settings_panel() -> void:
	## 初始化音量滑块和全屏复选框
	var vol_slider: HSlider = _settings_panel.get_node_or_null("VBoxContainer/VolumeSlider")
	if vol_slider:
		vol_slider.value_changed.connect(_on_volume_changed)
		vol_slider.value = AudioManager.get_master_volume()

	var fullscreen_cb: CheckBox = _settings_panel.get_node_or_null("VBoxContainer/FullscreenCheck")
	if fullscreen_cb:
		fullscreen_cb.toggled.connect(_on_fullscreen_toggled)
		fullscreen_cb.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN

	# 删除存档按钮
	var delete_btn: Button = _settings_panel.get_node_or_null("VBoxContainer/DeleteSaveButton")
	if delete_btn:
		delete_btn.pressed.connect(_on_delete_save_pressed)
		delete_btn.disabled = not SaveManager.has_save(0)

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


func _on_delete_save_pressed() -> void:
	## 删除存档（带二次确认弹窗）
	_show_delete_confirm()


func _show_delete_confirm() -> void:
	## 显示删除确认对话框
	var confirm_dialog: ConfirmationDialog = ConfirmationDialog.new()
	confirm_dialog.name = "DeleteConfirmDialog"
	confirm_dialog.title = "确认删除"
	confirm_dialog.dialog_text = "确定要删除存档吗？\n此操作不可撤销！"
	confirm_dialog.get_ok_button().text = "删除"
	confirm_dialog.get_cancel_button().text = "取消"
	confirm_dialog.confirmed.connect(_do_delete_save)
	add_child(confirm_dialog)
	confirm_dialog.popup_centered()


func _do_delete_save() -> void:
	## 执行删除存档操作
	SaveManager.delete_save(0)
	_continue_btn.disabled = true
	_continue_btn.tooltip_text = "没有可用的存档"

	# 更新设置面板中的删除按钮状态
	var delete_btn: Button = _settings_panel.get_node_or_null("VBoxContainer/DeleteSaveButton")
	if delete_btn:
		delete_btn.disabled = true

	print("[MainMenu] 存档已删除")


func _on_settings_close() -> void:
	## 关闭设置面板 → 返回主菜单
	_settings_panel.hide()
	_dim_overlay.hide()
	$MenuContainer.show()


# ============================================================
# 按钮回调
# ============================================================

func _on_continue_pressed() -> void:
	## 继续游戏 → 读取存档 → 切换场景
	print("[MainMenu] 继续游戏")
	var fade := ColorRect.new()
	fade.name = "FadeOverlay"
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fade)
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, 0.4)
	tween.tween_callback(_switch_to_continue)


func _switch_to_continue() -> void:
	## 切换到游戏场景并恢复存档
	GameManager.continue_game(0)


func _on_start_pressed() -> void:
	## 开始新游戏 → 淡出 → 切换场景
	print("[MainMenu] 开始新游戏")
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

	# 更新删除按钮状态
	var delete_btn: Button = _settings_panel.get_node_or_null("VBoxContainer/DeleteSaveButton")
	if delete_btn:
		delete_btn.disabled = not SaveManager.has_save(0)

	# 面板弹入动画
	_settings_panel.scale = Vector2(0.9, 0.9)
	var tween := create_tween()
	tween.tween_property(_settings_panel, "scale", Vector2(1.0, 1.0), 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _on_quit_pressed() -> void:
	## 退出游戏
	print("[MainMenu] 退出游戏")
	get_tree().quit()
