extends CanvasLayer
## 升级选择UI（美化版）
## 负责：卡片风格三选项 / 稀有度光效 / Hover动画 / 点击反馈


# ============================================================
# 信号
# ============================================================

## 玩家选择了某个升级
signal option_selected(upgrade_data: Dictionary)


# ============================================================
# 导出变量（可在编辑器中调整）
# ============================================================

## 稀有度对应的主题色（含边框色、发光色）
@export var rarity_colors: Dictionary = {
	"common": {
		"border": Color(0.5, 0.5, 0.5, 0.8),
		"glow": Color(0.6, 0.6, 0.6, 0.3),
		"label": "普通",
	},
	"rare": {
		"border": Color(0.25, 0.5, 1.0, 0.9),
		"glow": Color(0.3, 0.5, 1.0, 0.35),
		"label": "稀有",
	},
	"epic": {
		"border": Color(0.65, 0.3, 1.0, 0.9),
		"glow": Color(0.6, 0.35, 1.0, 0.35),
		"label": "史诗",
	},
	"legendary": {
		"border": Color(1.0, 0.7, 0.15, 1.0),
		"glow": Color(1.0, 0.65, 0.1, 0.4),
		"label": "传说",
	},
}


# ============================================================
# 节点引用（@onready）
# ============================================================

@onready var _panel: Panel = %UpgradePanel
@onready var _dim_overlay: ColorRect = %DimOverlay
@onready var _option_buttons: Array[Button] = [
	%Option1,
	%Option2,
	%Option3,
]


# ============================================================
# 内部状态变量
# ============================================================

## 当前展示的升级数据
var _current_options: Array = []
## 每个选项的悬停 Tween
var _hover_tweens: Array[Tween] = []
## 稀有度发光 Tween（传说/史诗持续闪烁）
var _glow_tweens: Array[Tween] = []


# ============================================================
# 生命周期函数
# ============================================================

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("upgrade_ui")

	# 连接按钮信号
	for i in range(_option_buttons.size()):
		var idx: int = i
		_option_buttons[i].pressed.connect(_on_option_pressed.bind(idx))
		_option_buttons[i].mouse_entered.connect(_on_option_hovered.bind(idx, true))
		_option_buttons[i].mouse_exited.connect(_on_option_hovered.bind(idx, false))

	# 应用面板样式
	_apply_panel_style()

	hide()
	print("[UpgradeUI] 美化升级 UI 就绪")


# ============================================================
# 面板样式
# ============================================================

func _apply_panel_style() -> void:
	## 设置升级面板的暗黑卡片风格
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.06, 0.08, 0.95)
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.8, 0.7, 0.2, 0.6)
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	_panel.add_theme_stylebox_override("panel", panel_style)


# ============================================================
# 公共接口（供 UpgradeManager 调用）
# ============================================================

func show_options(options: Array) -> void:
	## 显示升级选项面板（带淡入动画）
	_current_options = options
	_glow_tweens.clear()
	_hover_tweens.clear()

	# 更新每个选项按钮
	for i in range(_option_buttons.size()):
		if i < options.size():
			_update_option_card(_option_buttons[i], options[i])
			_option_buttons[i].visible = true
		else:
			_option_buttons[i].visible = false

	# 淡入动画
	show()
	_dim_overlay.modulate.a = 0.0
	_panel.modulate.a = 0.0
	_panel.scale = Vector2(0.85, 0.85)

	var tween := create_tween().set_parallel(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_dim_overlay, "modulate:a", 0.7, 0.25)
	tween.tween_property(_panel, "modulate:a", 1.0, 0.25)
	tween.tween_property(_panel, "scale", Vector2(1.0, 1.0), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	print("[UpgradeUI] 展示 %d 个升级选项" % mini(options.size(), _option_buttons.size()))


func hide_options() -> void:
	## 隐藏升级选项面板
	# 清除所有悬停动画
	for tween in _hover_tweens:
		if tween and tween.is_valid():
			tween.kill()
	_hover_tweens.clear()
	for tween in _glow_tweens:
		if tween and tween.is_valid():
			tween.kill()
	_glow_tweens.clear()

	hide()
	_current_options.clear()


# ============================================================
# 选项卡片更新
# ============================================================

func _update_option_card(button: Button, data: Dictionary) -> void:
	## 构建卡片风格的升级选项
	var name_label: Label = button.find_child("NameLabel", true, false) as Label
	var desc_label: Label = button.find_child("DescLabel", true, false) as Label
	var icon_rect: ColorRect = button.find_child("IconRect", true, false) as ColorRect

	# 获取稀有度配置
	var rarity: String = data.get("rarity", "common")
	var color_cfg: Dictionary = rarity_colors.get(rarity, rarity_colors["common"])
	var border_color: Color = color_cfg["border"]
	var glow_color: Color = color_cfg["glow"]
	var rarity_label: String = color_cfg.get("label", "")

	# 设置名称（含稀有度标签）
	var upgrade_name: String = data.get("name", "???")
	if name_label:
		name_label.text = "[%s] %s" % [rarity_label, upgrade_name]
		name_label.add_theme_color_override("font_color", border_color)

	# 生成描述文本
	if desc_label:
		var desc_template: String = data.get("description", "")
		var value = data.get("value", 0)
		desc_label.text = desc_template.replace("{value}", str(value))

	# 图标区域 — 稀有度渐变
	if icon_rect:
		var darker := Color(border_color.r * 0.25, border_color.g * 0.25, border_color.b * 0.25, 1.0)
		icon_rect.material = _create_gradient_material(darker, glow_color)

	# 应用按钮卡片样式
	_apply_card_style(button, border_color, glow_color)

	# 重置按钮缩放（清除上次动画）
	button.scale = Vector2(1.0, 1.0)


func _create_gradient_material(from_color: Color, to_color: Color) -> ShaderMaterial:
	## 创建简单的垂直渐变材质（用于图标区域）
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
uniform vec4 top_color : source_color;
uniform vec4 bottom_color : source_color;

void fragment() {
	COLOR = mix(top_color, bottom_color, UV.y);
}"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("top_color", to_color)
	mat.set_shader_parameter("bottom_color", from_color)
	return mat


func _apply_card_style(button: Button, border_color: Color, glow_color: Color) -> void:
	## 设置按钮的卡片式样（正常/悬停/按下三态）

	# —— 正常态 ——
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.09, 0.09, 0.11, 0.9)
	normal.border_width_left = 2
	normal.border_width_right = 2
	normal.border_width_top = 2
	normal.border_width_bottom = 2
	normal.border_color = border_color
	normal.corner_radius_top_left = 8
	normal.corner_radius_top_right = 8
	normal.corner_radius_bottom_left = 8
	normal.corner_radius_bottom_right = 8
	normal.shadow_size = 4
	normal.shadow_color = Color(0, 0, 0, 0.4)
	button.add_theme_stylebox_override("normal", normal)

	# —— 悬停态 ——
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.14, 0.14, 0.17, 0.95)
	hover.border_width_left = 2
	hover.border_width_right = 2
	hover.border_width_top = 2
	hover.border_width_bottom = 2
	hover.border_color = glow_color
	hover.corner_radius_top_left = 8
	hover.corner_radius_top_right = 8
	hover.corner_radius_bottom_left = 8
	hover.corner_radius_bottom_right = 8
	hover.shadow_size = 8
	hover.shadow_color = glow_color
	button.add_theme_stylebox_override("hover", hover)

	# —— 按下态 ——
	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(0.06, 0.06, 0.08, 0.95)
	pressed.border_width_left = 2
	pressed.border_width_right = 2
	pressed.border_width_top = 2
	pressed.border_width_bottom = 2
	pressed.border_color = border_color.lerp(Color.WHITE, 0.3)
	pressed.corner_radius_top_left = 8
	pressed.corner_radius_top_right = 8
	pressed.corner_radius_bottom_left = 8
	pressed.corner_radius_bottom_right = 8
	pressed.shadow_size = 2
	pressed.shadow_color = Color(0, 0, 0, 0.3)
	button.add_theme_stylebox_override("pressed", pressed)

	# —— 字体颜色 ——
	button.add_theme_color_override("font_color", Color(0.85, 0.85, 0.8, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.95, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.9, 0.9, 0.85, 1.0))


# ============================================================
# 悬停动画
# ============================================================

func _on_option_hovered(index: int, entered: bool) -> void:
	## 鼠标进入/离开卡片时的缩放动画
	if index >= _option_buttons.size():
		return

	var button: Button = _option_buttons[index]

	# 清除旧 tween
	if index < _hover_tweens.size() and _hover_tweens[index] and _hover_tweens[index].is_valid():
		_hover_tweens[index].kill()

	# 确保数组长度
	while _hover_tweens.size() <= index:
		_hover_tweens.append(null)

	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if entered:
		tw.tween_property(button, "scale", Vector2(1.05, 1.05), 0.15).set_ease(Tween.EASE_OUT)
	else:
		tw.tween_property(button, "scale", Vector2(1.0, 1.0), 0.15).set_ease(Tween.EASE_OUT)
	_hover_tweens[index] = tw


# ============================================================
# 按钮回调
# ============================================================

func _on_option_pressed(index: int) -> void:
	## 玩家点击某个升级选项 — 播放选中动画后通知 UpgradeManager
	if index >= _current_options.size():
		return

	var selected: Dictionary = _current_options[index]
	print("[UpgradeUI] 玩家选择: %s" % selected.get("name", "???"))

	# 点击动画：按钮快速缩小再放大
	var button: Button = _option_buttons[index]
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(button, "scale", Vector2(0.92, 0.92), 0.06)
	tw.tween_property(button, "scale", Vector2(1.05, 1.05), 0.1)
	tw.tween_property(button, "scale", Vector2(1.0, 1.0), 0.08)
	tw.tween_callback(_apply_and_notify.bind(selected)).set_delay(0.05)


func _apply_and_notify(data: Dictionary) -> void:
	## 通知 UpgradeManager 应用升级
	var manager: Node = _find_upgrade_manager()
	if manager and manager.has_method("apply_upgrade"):
		manager.apply_upgrade(data)
	else:
		push_error("[UpgradeUI] 未找到 UpgradeManager，无法应用升级")


func _find_upgrade_manager() -> Node:
	## 查找场景中的 UpgradeManager
	var managers := get_tree().get_nodes_in_group("upgrade_manager")
	if managers.is_empty():
		return null
	return managers[0]
