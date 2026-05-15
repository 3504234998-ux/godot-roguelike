extends CanvasLayer
## Boss 警报 UI（美化版）
## 负责：Boss 出现时显示红色警告 / 屏幕闪烁 / 滑入+淡出动画


# ============================================================
# 导出变量（可在编辑器中调整）
# ============================================================

## 警告文字显示时长（秒）
@export var display_time: float = 2.5

## 闪烁次数
@export var flash_count: int = 3


# ============================================================
# 节点引用（@onready）
# ============================================================

@onready var _panel: Panel = $AlertPanel
@onready var _flash_overlay: ColorRect = $FlashOverlay


# ============================================================
# 内部状态变量
# ============================================================

var _timer: float = 0.0
var _active: bool = false


# ============================================================
# 生命周期函数
# ============================================================

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("boss_alert")

	# 应用面板样式
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.04, 0.04, 0.95)
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.9, 0.2, 0.2, 0.8)
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_left = 10
	panel_style.corner_radius_bottom_right = 10
	_panel.add_theme_stylebox_override("panel", panel_style)

	hide()


func _process(delta: float) -> void:
	if not _active:
		return

	_timer -= delta
	# 最后 0.6 秒淡出
	var fade_threshold: float = 0.6
	var fade_ratio: float = clampf(_timer / fade_threshold, 0.0, 1.0) if _timer < fade_threshold else 1.0
	_panel.modulate.a = fade_ratio

	if _timer <= 0.0:
		_active = false
		hide()
		_panel.modulate.a = 1.0
		_panel.scale = Vector2(1.0, 1.0)


# ============================================================
# 公共接口
# ============================================================

func show_alert() -> void:
	## 显示 Boss 警告（带动画序列：屏幕闪烁 → 面板滑入 → 保持 → 淡出）
	_timer = display_time
	_active = true
	_panel.modulate.a = 1.0

	# 面板从上方滑入
	_panel.position.y = -150.0
	show()

	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_panel, "position:y", 0.0, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	# 屏幕红色闪烁（短暂出现再消失，重复 flash_count 次）
	_flash_overlay.color.a = 0.0
	var flash_tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	for i in range(flash_count):
		flash_tween.tween_property(_flash_overlay, "color:a", 0.3, 0.12)
		flash_tween.tween_property(_flash_overlay, "color:a", 0.0, 0.12)
	# 最后一次停留在微弱红色
	flash_tween.tween_property(_flash_overlay, "color:a", 0.05, 0.2)
	flash_tween.tween_property(_flash_overlay, "color:a", 0.0, 0.5)

	print("[BossAlert] Boss 出现！警告动画播放中")
