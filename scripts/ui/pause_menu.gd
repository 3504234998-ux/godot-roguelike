extends CanvasLayer
## 暂停菜单 UI
## 负责：暂停时显示菜单 / 继续游戏 / 重新开始 / 保存并退出 / 返回主菜单


# ============================================================
# 节点引用（@onready）
# ============================================================

@onready var _panel: Panel = $CenterPanel
@onready var _overlay: ColorRect = $DimOverlay
@onready var _vbox: VBoxContainer = $CenterPanel/VBoxContainer
@onready var _resume_btn: Button = $CenterPanel/VBoxContainer/ResumeButton
@onready var _restart_btn: Button = $CenterPanel/VBoxContainer/RestartButton
@onready var _quit_btn: Button = $CenterPanel/VBoxContainer/QuitButton

## 保存并退出按钮（动态创建）
var _save_quit_btn: Button = null


# ============================================================
# 生命周期函数
# ============================================================

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("pause_menu")

	# 创建"保存并退出"按钮（插入到退出按钮上方）
	_create_save_quit_button()

	# 连接按钮信号
	_resume_btn.pressed.connect(_on_resume_pressed)
	_restart_btn.pressed.connect(_on_restart_pressed)
	_quit_btn.pressed.connect(_on_quit_pressed)

	# 连接 GameManager 信号
	GameManager.game_paused.connect(_on_game_paused)
	GameManager.game_resumed.connect(_on_game_resumed)

	# 应用按钮样式
	_apply_button_styles()
	_adjust_panel_size()

	hide()
	print("[PauseMenu] 暂停菜单就绪")


# ============================================================
# 保存并退出按钮（动态创建）
# ============================================================

func _create_save_quit_button() -> void:
	## 在退出按钮上方插入"保存并退出"按钮
	_save_quit_btn = Button.new()
	_save_quit_btn.name = "SaveQuitButton"
	_save_quit_btn.text = "保存并退出"
	_save_quit_btn.custom_minimum_size = Vector2(200, 34)

	_save_quit_btn.pressed.connect(_on_save_quit_pressed)

	# 插入到退出按钮之前
	_vbox.add_child(_save_quit_btn)
	var quit_idx: int = _quit_btn.get_index()
	_vbox.move_child(_save_quit_btn, quit_idx)


# ============================================================
# 样式应用
# ============================================================

func _apply_button_styles() -> void:
	## 统一设置按钮的暗黑风格样式
	var buttons: Array[Button] = [_save_quit_btn, _resume_btn, _restart_btn, _quit_btn]
	for btn in buttons:
		if not btn:
			continue
		# 普通状态
		var normal := StyleBoxFlat.new()
		normal.bg_color = Color(0.15, 0.15, 0.15, 0.9)
		normal.border_width_left = 2
		normal.border_width_right = 2
		normal.border_width_top = 2
		normal.border_width_bottom = 2
		normal.border_color = Color(0.4, 0.4, 0.4, 0.8)
		normal.corner_radius_top_left = 6
		normal.corner_radius_top_right = 6
		normal.corner_radius_bottom_left = 6
		normal.corner_radius_bottom_right = 6
		normal.content_margin_left = 16
		normal.content_margin_right = 16
		btn.add_theme_stylebox_override("normal", normal)

		# 悬停状态
		var hover := StyleBoxFlat.new()
		hover.bg_color = Color(0.25, 0.25, 0.25, 0.95)
		hover.border_width_left = 2
		hover.border_width_right = 2
		hover.border_width_top = 2
		hover.border_width_bottom = 2
		hover.border_color = Color(0.7, 0.7, 0.7, 0.9)
		hover.corner_radius_top_left = 6
		hover.corner_radius_top_right = 6
		hover.corner_radius_bottom_left = 6
		hover.corner_radius_bottom_right = 6
		hover.content_margin_left = 16
		hover.content_margin_right = 16
		btn.add_theme_stylebox_override("hover", hover)

		# 按下状态
		var pressed := StyleBoxFlat.new()
		pressed.bg_color = Color(0.1, 0.1, 0.1, 0.95)
		pressed.border_width_left = 2
		pressed.border_width_right = 2
		pressed.border_width_top = 2
		pressed.border_width_bottom = 2
		pressed.border_color = Color(0.5, 0.5, 0.5, 0.8)
		pressed.corner_radius_top_left = 6
		pressed.corner_radius_top_right = 6
		pressed.corner_radius_bottom_left = 6
		pressed.corner_radius_bottom_right = 6
		pressed.content_margin_left = 16
		pressed.content_margin_right = 16
		btn.add_theme_stylebox_override("pressed", pressed)

		# 字体颜色
		btn.add_theme_color_override("font_color", Color(0.85, 0.85, 0.8, 1.0))
		btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.95, 1.0))
		btn.add_theme_font_size_override("font_size", 15)

	# 缩小 VBoxContainer 按钮间距
	_vbox.add_theme_constant_override("separation", 4)


func _adjust_panel_size() -> void:
	## 根据按钮数量动态调整面板最小高度
	# 统一所有按钮高度（包括 .tscn 中原有的按钮）
	for btn in [_save_quit_btn, _resume_btn, _restart_btn, _quit_btn]:
		if btn:
			btn.custom_minimum_size = Vector2(200, 34)

	var btn_count: int = _vbox.get_child_count()
	var btn_height: float = 34.0
	var separation: float = 4.0
	var padding: float = 32.0
	var total_h: float = btn_count * btn_height + (btn_count - 1) * separation + padding
	_panel.custom_minimum_size = Vector2(240, total_h)


# ============================================================
# 信号回调
# ============================================================

func _on_game_paused() -> void:
	## 游戏暂停 → 显示菜单（升级时跳过，避免遮挡升级UI）
	if GameManager.is_upgrading:
		return
	show()
	# 淡入动画
	_overlay.modulate.a = 0.0
	_panel.modulate.a = 0.0
	var tween := create_tween().set_parallel(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_overlay, "modulate:a", 0.6, 0.25)
	tween.tween_property(_panel, "modulate:a", 1.0, 0.25)


func _on_game_resumed() -> void:
	## 游戏恢复 → 隐藏菜单
	hide()


func _on_resume_pressed() -> void:
	## 继续游戏按钮
	GameManager.resume_game()


func _on_restart_pressed() -> void:
	## 重新开始按钮
	GameManager.restart_game()


func _on_save_quit_pressed() -> void:
	## 保存并退出按钮 → 保存存档后返回主菜单
	print("[PauseMenu] 保存并退出")
	GameManager.save_and_quit()


func _on_quit_pressed() -> void:
	## 返回主菜单按钮（不保存）
	GameManager.return_to_menu()
