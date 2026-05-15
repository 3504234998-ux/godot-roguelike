extends CanvasLayer
## HUD 控制器（美化版）
## 负责：TextureProgressBar 血量/经验条 / 等级 / 时间 / 动态渐变 / 暗黑风格


# ============================================================
# 节点引用（@onready）
# ============================================================

@onready var _hp_bar: TextureProgressBar = %HPBar
@onready var _hp_label: Label = %HPLabel
@onready var _exp_bar: TextureProgressBar = %ExpBar
@onready var _level_label: Label = %LevelLabel
@onready var _time_label: Label = %TimeLabel
@onready var _info_panel: Panel = $InfoPanel
@onready var _time_panel: Panel = $TimePanel


# ============================================================
# 内部状态变量
# ============================================================

## 上一次血量比例（用于判断是否需要更新渐变纹理）
var _last_hp_ratio: float = 1.0

## 生成的纹理缓存
var _hp_fill_texture: ImageTexture = null
var _hp_under_texture: ImageTexture = null
var _exp_fill_texture: ImageTexture = null
var _exp_under_texture: ImageTexture = null

## HP 条脉冲动画 tween
var _hp_pulse_tween: Tween = null


# ============================================================
# 生命周期函数
# ============================================================

func _ready() -> void:
	# 生成渐变纹理
	_generate_textures()

	# 应用面板和条的样式
	_apply_panel_styles()
	_apply_bar_styles()

	# 连接玩家信号
	call_deferred("_connect_player_signals")

	print("[HUD] 美化 UI 系统就绪")


func _process(_delta: float) -> void:
	_update_time_display()


# ============================================================
# 纹理生成
# ============================================================

func _generate_textures() -> void:
	## 生成所有需要的渐变纹理（运行时动态创建，无需外部图片资源）
	# HP 底条 — 深暗色
	_hp_under_texture = _make_gradient(200, 16, [
		Color(0.08, 0.05, 0.05, 1.0),
		Color(0.08, 0.05, 0.05, 1.0),
	])

	# HP 填充 — 初始绿色（会根据血量动态更新）
	_hp_fill_texture = _make_gradient(200, 16, [
		Color(0.15, 0.7, 0.2, 1.0),
		Color(0.1, 0.85, 0.25, 1.0),
	])

	# EXP 底条 — 深暗紫
	_exp_under_texture = _make_gradient(200, 12, [
		Color(0.05, 0.04, 0.12, 1.0),
		Color(0.05, 0.04, 0.12, 1.0),
	])

	# EXP 填充 — 蓝紫渐变
	_exp_fill_texture = _make_gradient(200, 12, [
		Color(0.2, 0.35, 0.8, 1.0),
		Color(0.4, 0.25, 0.9, 1.0),
	])


func _make_gradient(width: int, height: int, colors: Array) -> ImageTexture:
	## 创建水平渐变纹理（从左到右 lerp）
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	for x in range(width):
		var t: float = float(x) / float(width - 1) if width > 1 else 0.0
		var color: Color
		if colors.size() == 1:
			color = colors[0]
		elif colors.size() == 2:
			color = colors[0].lerp(colors[1], t)
		else:
			# 多色渐变：分段 lerp
			var segment: float = 1.0 / float(colors.size() - 1)
			var seg_idx: int = mini(int(t / segment), colors.size() - 2)
			var local_t: float = (t - seg_idx * segment) / segment
			color = colors[seg_idx].lerp(colors[seg_idx + 1], local_t)
		for y in range(height):
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)


# ============================================================
# 样式应用
# ============================================================

func _apply_panel_styles() -> void:
	## 设置面板的暗黑半透明风格
	for panel: Panel in [_info_panel, _time_panel]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.04, 0.04, 0.06, 0.75)
		style.border_width_left = 1
		style.border_width_right = 1
		style.border_width_top = 1
		style.border_width_bottom = 1
		style.border_color = Color(0.25, 0.25, 0.3, 0.5)
		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
		style.corner_radius_bottom_left = 6
		style.corner_radius_bottom_right = 6
		panel.add_theme_stylebox_override("panel", style)


func _apply_bar_styles() -> void:
	## 将渐变纹理应用到 TextureProgressBar 上
	# HP 条
	_hp_bar.texture_under = _hp_under_texture
	_hp_bar.texture_progress = _hp_fill_texture

	# EXP 条
	_exp_bar.texture_under = _exp_under_texture
	_exp_bar.texture_progress = _exp_fill_texture


# ============================================================
# 信号连接
# ============================================================

func _connect_player_signals() -> void:
	## 查找玩家节点，连接其子组件的信号到 UI 更新函数
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		push_warning("[HUD] 未找到玩家节点，信号未连接")
		return

	var player: Node = players[0]

	# 连接血量信号
	var health: Node = player.get_node_or_null("HealthController")
	if health and health.has_signal("health_changed"):
		health.health_changed.connect(_on_health_changed)
		if health.has_method("get_hp_ratio"):
			_on_health_changed(health.current_hp, health.max_hp)

	# 连接等级 / 经验信号
	var level: Node = player.get_node_or_null("LevelController")
	if level and level.has_signal("leveled_up"):
		level.leveled_up.connect(_on_level_up)
	if level and level.has_signal("exp_changed"):
		level.exp_changed.connect(_on_exp_changed)
	if level:
		_on_level_up(level.current_level)
		if level.has_method("get_exp_ratio"):
			_on_exp_changed(level.current_exp, level.get_exp_to_next())


# ============================================================
# UI 更新函数（由信号触发）
# ============================================================

func _on_health_changed(current: int, maximum: int) -> void:
	## 响应血量变化信号 → 更新血条数值 + 动态渐变颜色
	_hp_bar.max_value = maximum
	_hp_bar.value = current
	_hp_label.text = "%d/%d" % [current, maximum]

	# 根据血量比例更新渐变颜色
	var ratio: float = float(current) / float(maximum) if maximum > 0 else 0.0
	if abs(ratio - _last_hp_ratio) > 0.01:
		_last_hp_ratio = ratio
		_update_hp_gradient(ratio)

	# 低血量脉冲动画
	if ratio < 0.3 and ratio > 0.0:
		_start_hp_pulse()
	else:
		_stop_hp_pulse()


func _on_exp_changed(current: int, needed: int) -> void:
	## 响应经验变化信号 → 更新经验条
	_exp_bar.max_value = needed
	_exp_bar.value = current


func _on_level_up(new_level: int) -> void:
	## 响应升级信号 → 更新等级显示 + 播放闪光动画
	_level_label.text = "Lv. %d" % new_level
	_flash_label(_level_label, Color(1.0, 0.9, 0.3, 1.0), 0.5)


func _update_time_display() -> void:
	## 从 GameManager 读取时间并更新显示
	var t: float = GameManager.get_elapsed_time()
	var total: int = int(t)
	var minutes: int = total / 60
	var seconds: int = total % 60
	_time_label.text = "%02d:%02d" % [minutes, seconds]


# ============================================================
# HP 渐变更新
# ============================================================

func _update_hp_gradient(ratio: float) -> void:
	## 根据血量比例生成对应颜色的渐变纹理
	# > 60%: 绿色 → 亮绿
	# 30%-60%: 黄色 → 橙色
	# < 30%: 红色 → 暗红
	var base: Color
	var highlight: Color

	if ratio > 0.6:
		var t: float = (ratio - 0.6) / 0.4
		base = Color(0.12, 0.55 + t * 0.15, 0.15, 1.0)
		highlight = Color(0.1, 0.7 + t * 0.2, 0.2, 1.0)
	elif ratio > 0.3:
		var t: float = (ratio - 0.3) / 0.3
		base = Color(0.6 + t * 0.2, 0.4 + t * 0.2, 0.08, 1.0)
		highlight = Color(0.8 + t * 0.1, 0.55 + t * 0.25, 0.1, 1.0)
	else:
		var t: float = ratio / 0.3
		base = Color(0.65 + t * 0.15, 0.1 + t * 0.1, 0.08, 1.0)
		highlight = Color(0.9, 0.12 + t * 0.15, 0.1, 1.0)

	_hp_fill_texture = _make_gradient(200, 16, [base, highlight])
	_hp_bar.texture_progress = _hp_fill_texture


# ============================================================
# HP 低血量脉冲动画
# ============================================================

func _start_hp_pulse() -> void:
	## 低血量时模块化的红色脉冲
	if _hp_pulse_tween and _hp_pulse_tween.is_valid():
		return

	_hp_pulse_tween = create_tween().set_loops()
	_hp_pulse_tween.tween_property(_hp_bar, "modulate", Color(1.0, 0.6, 0.6, 1.0), 0.4)
	_hp_pulse_tween.tween_property(_hp_bar, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.4)


func _stop_hp_pulse() -> void:
	## 停止脉冲动画并恢复颜色
	if _hp_pulse_tween and _hp_pulse_tween.is_valid():
		_hp_pulse_tween.kill()
	_hp_pulse_tween = null
	_hp_bar.modulate = Color(1, 1, 1, 1)


# ============================================================
# 文字闪光动画
# ============================================================

func _flash_label(label: Label, color: Color, duration: float) -> void:
	## 短暂高亮某个标签（升级时闪烁）
	var original := label.get_theme_color("font_color")
	if original == Color():
		original = Color(1.0, 0.85, 0.2, 1.0)
	var tween := create_tween()
	tween.tween_property(label, "modulate", color, 0.1)
	tween.tween_property(label, "modulate", original, duration)
	label.modulate = original


# ============================================================
# 公共接口
# ============================================================

func get_game_time() -> float:
	## 获取当前游戏时间（秒）
	return GameManager.get_elapsed_time()
