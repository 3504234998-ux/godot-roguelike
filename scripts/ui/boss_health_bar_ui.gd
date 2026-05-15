extends CanvasLayer
## Boss 血量条 UI（美化版）
## 负责：屏幕顶部红色主题 Boss 血条 / 动态渐变 / 显示/隐藏动画


# ============================================================
# 节点引用（@onready）
# ============================================================

@onready var _bar: TextureProgressBar = $Panel/MarginContainer/VBoxContainer/Bar
@onready var _label: Label = $Panel/MarginContainer/VBoxContainer/HeaderBox/NameLabel
@onready var _hp_text: Label = $Panel/MarginContainer/VBoxContainer/HeaderBox/HPText
@onready var _panel: Panel = $Panel


# ============================================================
# 内部状态变量
# ============================================================

## 当前追踪的 Boss 引用
var _boss: CharacterBody2D = null

## 渐变纹理缓存
var _fill_texture: ImageTexture = null
var _under_texture: ImageTexture = null


# ============================================================
# 生命周期函数
# ============================================================

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("boss_hp_bar")

	# 生成纹理
	_generate_textures()

	# 应用样式
	_apply_styles()

	hide()


func _process(_delta: float) -> void:
	# 检查 Boss 是否仍然存活
	if not is_instance_valid(_boss):
		hide()
		_boss = null


# ============================================================
# 纹理生成
# ============================================================

func _generate_textures() -> void:
	## 生成 Boss 血条的暗红渐变色纹理
	# 底条 — 深血红
	_under_texture = _make_gradient(400, 18, [
		Color(0.12, 0.03, 0.03, 1.0),
		Color(0.12, 0.03, 0.03, 1.0),
	])

	# 填充条 — 血红到亮红
	_fill_texture = _make_gradient(400, 18, [
		Color(0.7, 0.08, 0.08, 1.0),
		Color(0.95, 0.12, 0.12, 1.0),
	])


func _make_gradient(width: int, height: int, colors: Array) -> ImageTexture:
	## 创建水平渐变纹理
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	for x in range(width):
		var t: float = float(x) / float(width - 1) if width > 1 else 0.0
		var color: Color
		if colors.size() == 1:
			color = colors[0]
		elif colors.size() == 2:
			color = colors[0].lerp(colors[1], t)
		else:
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

func _apply_styles() -> void:
	## 设置面板和血条的暗黑血色风格
	# 面板样式
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.04, 0.04, 0.9)
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.6, 0.15, 0.15, 0.7)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	_panel.add_theme_stylebox_override("panel", panel_style)

	# 血条纹理
	_bar.texture_under = _under_texture
	_bar.texture_progress = _fill_texture


# ============================================================
# 公共接口
# ============================================================

func bind_boss(boss: CharacterBody2D, boss_name: String) -> void:
	## 绑定 Boss 并显示血条（带滑入动画）
	_boss = boss

	# 获取 Boss 血量
	var health: Node = boss.get_node_or_null("Health")
	if health:
		_bar.max_value = health.max_hp
		_bar.value = health.current_hp
		_hp_text.text = "%d / %d" % [health.current_hp, health.max_hp]
		if health.has_signal("health_changed"):
			health.health_changed.connect(_on_boss_health_changed)

	_label.text = boss_name
	show()

	# 滑入动画（等待一帧确保 _panel 已渲染，size 非零）
	await get_tree().process_frame
	_panel.position.y = -_panel.size.y
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_panel, "position:y", 0.0, 0.3).set_ease(Tween.EASE_OUT)


func unbind() -> void:
	## 解除 Boss 绑定并滑出隐藏
	_boss = null
	if not _panel:
		hide()
		return
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_panel, "position:y", -_panel.size.y - 10, 0.2).set_ease(Tween.EASE_IN)
	tween.tween_callback(hide)


func _on_boss_health_changed(current: int, _max: int) -> void:
	## Boss 血量变化回调 → 更新条 + 文字
	_bar.value = current
	_hp_text.text = "%d / %d" % [current, _bar.max_value]

	# 低血量时更新为更红的渐变
	var ratio: float = float(current) / float(_bar.max_value) if _bar.max_value > 0 else 0.0
	if ratio < 0.3:
		_fill_texture = _make_gradient(400, 18, [
			Color(0.9, 0.05, 0.05, 1.0),
			Color(1.0, 0.15, 0.08, 1.0),
		])
		_bar.texture_progress = _fill_texture
		# 脉冲效果
		var tw := create_tween().set_loops().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_property(_bar, "modulate", Color(1.0, 0.5, 0.5, 1.0), 0.3)
		tw.tween_property(_bar, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.3)
