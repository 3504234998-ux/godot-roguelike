extends CanvasLayer
## 暂停菜单 UI
## 负责：暂停时显示菜单 / 继续游戏 / 重新开始 / 返回主菜单


# ============================================================
# 节点引用（@onready）
# ============================================================

@onready var _panel: Panel = $CenterPanel
@onready var _overlay: ColorRect = $DimOverlay
@onready var _resume_btn: Button = $CenterPanel/VBoxContainer/ResumeButton
@onready var _restart_btn: Button = $CenterPanel/VBoxContainer/RestartButton
@onready var _quit_btn: Button = $CenterPanel/VBoxContainer/QuitButton


# ============================================================
# 生命周期函数
# ============================================================

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("pause_menu")

	# 连接按钮信号
	_resume_btn.pressed.connect(_on_resume_pressed)
	_restart_btn.pressed.connect(_on_restart_pressed)
	_quit_btn.pressed.connect(_on_quit_pressed)

	# 连接 GameManager 信号
	GameManager.game_paused.connect(_on_game_paused)
	GameManager.game_resumed.connect(_on_game_resumed)

	# 应用按钮样式
	_apply_button_styles()

	hide()
	print("[PauseMenu] 暂停菜单就绪")


# ============================================================
# 样式应用
# ============================================================

func _apply_button_styles() -> void:
	## 统一设置按钮的暗黑风格样式
	var buttons: Array[Button] = [_resume_btn, _restart_btn, _quit_btn]
	for btn in buttons:
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
		btn.add_theme_font_size_override("font_size", 16)


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


func _on_quit_pressed() -> void:
	## 返回主菜单按钮
	GameManager.return_to_menu()
