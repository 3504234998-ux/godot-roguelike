extends Node2D
## 敌人头顶血条组件（精英怪/Boss）
## 负责：在敌人头顶显示血量条 / 精细边框 / 颜色随血量变化


# ============================================================
# 导出变量（可在编辑器中调整）
# ============================================================

## 血条宽度（像素）
@export var bar_width: float = 40.0

## 血条高度（像素）
@export var bar_height: float = 5.0

## 血条头顶偏移（像素）
@export var y_offset: float = -30.0


# ============================================================
# 节点引用（@onready）
# ============================================================

@onready var _bar_bg: ColorRect = $BarBG
@onready var _bar_border: ColorRect = $BarBorder
@onready var _bar_fill: ColorRect = $BarFill


# ============================================================
# 内部状态变量
# ============================================================

var _max_hp: int = 1


# ============================================================
# 生命周期函数
# ============================================================

func _ready() -> void:
	# 设置各层尺寸
	_bar_fill.size = Vector2(bar_width, bar_height)
	_bar_bg.size = Vector2(bar_width, bar_height)
	_bar_border.size = Vector2(bar_width + 2, bar_height + 1)
	# 将边框居中（比填充稍大一圈）
	_bar_border.position.x = -1
	_bar_border.position.y = -0.5
	position.y = y_offset


# ============================================================
# 公共接口
# ============================================================

func setup(max_hp: int) -> void:
	## 初始化血条
	_max_hp = maxi(max_hp, 1)
	_update_bar(1.0)


func update_hp(current_hp: int) -> void:
	## 更新血量显示
	var ratio: float = clampf(float(current_hp) / float(_max_hp), 0.0, 1.0)
	_update_bar(ratio)

	# 血量低于30% 变暗红色，否则亮红色
	if ratio < 0.3:
		_bar_fill.color = Color(0.85, 0.12, 0.12, 1.0)
	else:
		_bar_fill.color = Color(1.0, 0.25, 0.25, 1.0)


func _update_bar(ratio: float) -> void:
	## 更新血条填充宽度
	_bar_fill.size.x = bar_width * ratio
