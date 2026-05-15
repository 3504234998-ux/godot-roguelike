extends CanvasLayer
## 游戏结束 UI
## 负责：死亡后显示结算面板 / 动画 / 重新开始


# ============================================================
# 节点引用（@onready）
# ============================================================

@onready var _panel: Panel = $CenterPanel
@onready var _overlay: ColorRect = $DimOverlay
@onready var _time_label: Label = $CenterPanel/VBoxContainer/StatsContainer/TimeLabel
@onready var _kill_label: Label = $CenterPanel/VBoxContainer/StatsContainer/KillLabel
@onready var _level_label: Label = $CenterPanel/VBoxContainer/StatsContainer/LevelLabel
@onready var _restart_btn: Button = $CenterPanel/VBoxContainer/RestartButton
@onready var _quit_btn: Button = $CenterPanel/VBoxContainer/QuitButton


# ============================================================
# 生命周期函数
# ============================================================

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("game_over_ui")

	# 连接按钮
	_restart_btn.pressed.connect(_on_restart_pressed)
	_quit_btn.pressed.connect(_on_quit_pressed)

	# 监听游戏结束信号
	GameManager.game_over.connect(_on_game_over)

	# 应用样式
	_apply_panel_style()
	_apply_button_styles()

	hide()
	print("[GameOverUI] 游戏结束 UI 就绪")


# ============================================================
# 样式应用
# ============================================================

func _apply_panel_style() -> void:
	## 设置面板暗黑风格背景
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.08, 0.1, 0.95)
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.8, 0.2, 0.2, 0.7)
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_left = 10
	panel_style.corner_radius_bottom_right = 10
	_panel.add_theme_stylebox_override("panel", panel_style)


func _apply_button_styles() -> void:
	## 设置按钮暗黑风格
	var buttons: Array[Button] = [_restart_btn, _quit_btn]
	for btn in buttons:
		var normal := StyleBoxFlat.new()
		normal.bg_color = Color(0.15, 0.12, 0.12, 0.9)
		normal.border_width_left = 2
		normal.border_width_right = 2
		normal.border_width_top = 2
		normal.border_width_bottom = 2
		normal.border_color = Color(0.5, 0.3, 0.3, 0.8)
		normal.corner_radius_top_left = 6
		normal.corner_radius_top_right = 6
		normal.corner_radius_bottom_left = 6
		normal.corner_radius_bottom_right = 6
		normal.content_margin_left = 16
		normal.content_margin_right = 16
		btn.add_theme_stylebox_override("normal", normal)

		var hover := StyleBoxFlat.new()
		hover.bg_color = Color(0.25, 0.18, 0.18, 0.95)
		hover.border_width_left = 2
		hover.border_width_right = 2
		hover.border_width_top = 2
		hover.border_width_bottom = 2
		hover.border_color = Color(0.9, 0.4, 0.4, 0.8)
		hover.corner_radius_top_left = 6
		hover.corner_radius_top_right = 6
		hover.corner_radius_bottom_left = 6
		hover.corner_radius_bottom_right = 6
		hover.content_margin_left = 16
		hover.content_margin_right = 16
		btn.add_theme_stylebox_override("hover", hover)

		var pressed := StyleBoxFlat.new()
		pressed.bg_color = Color(0.1, 0.08, 0.08, 0.95)
		pressed.border_width_left = 2
		pressed.border_width_right = 2
		pressed.border_width_top = 2
		pressed.border_width_bottom = 2
		pressed.border_color = Color(0.6, 0.35, 0.35, 0.8)
		pressed.corner_radius_top_left = 6
		pressed.corner_radius_top_right = 6
		pressed.corner_radius_bottom_left = 6
		pressed.corner_radius_bottom_right = 6
		pressed.content_margin_left = 16
		pressed.content_margin_right = 16
		btn.add_theme_stylebox_override("pressed", pressed)

		btn.add_theme_color_override("font_color", Color(0.85, 0.8, 0.8, 1.0))
		btn.add_theme_color_override("font_hover_color", Color(1.0, 0.9, 0.9, 1.0))
		btn.add_theme_font_size_override("font_size", 15)


# ============================================================
# 信号回调
# ============================================================

func _on_game_over(total_time: float) -> void:
	## 游戏结束 → 填充数据 → 播放动画 → 显示
	var total: int = int(total_time)
	var minutes: int = total / 60
	var seconds: int = total % 60
	_time_label.text = "存活时间: %02d:%02d" % [minutes, seconds]

	# 获取击杀数（从 EnemyManager 累加统计）
	var kill_count: int = _get_kill_count()
	_kill_label.text = "击杀敌人: %d" % kill_count

	# 获取最终等级
	var level: int = _get_player_level()
	_level_label.text = "最终等级: %d" % level

	# 播放淡入动画
	show()
	_overlay.modulate.a = 0.0
	_panel.modulate.a = 0.0
	_panel.scale = Vector2(0.6, 0.6)

	var tween := create_tween().set_parallel(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_panel, "modulate:a", 1.0, 0.5)
	tween.tween_property(_overlay, "modulate:a", 0.85, 0.5)
	tween.tween_property(_panel, "scale", Vector2(1.0, 1.0), 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


# ============================================================
# 数据采集
# ============================================================

func _get_kill_count() -> int:
	## 从 GameManager 获取击杀数（如有统计系统）
	# 当前项目暂未实现全局击杀计数，返回 0 占位
	if GameManager.has_method("get_kill_count"):
		return GameManager.get_kill_count()
	return 0


func _get_player_level() -> int:
	## 查找玩家获取最终等级
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return 1
	var lv_ctrl: Node = players[0].get_node_or_null("LevelController")
	if lv_ctrl:
		return lv_ctrl.current_level
	return 1


# ============================================================
# 按钮回调
# ============================================================

func _on_restart_pressed() -> void:
	## 重新开始游戏
	GameManager.restart_game()


func _on_quit_pressed() -> void:
	## 返回主菜单
	GameManager.return_to_menu()
