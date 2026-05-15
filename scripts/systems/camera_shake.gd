extends Node
## 相机震动组件
## 负责：挂载在 Camera2D 上 / 提供 shake() 接口 / 支持多层震动叠加


# ============================================================
# 内部状态变量
# ============================================================

## 当前震动强度（叠加最大值）
var _trauma: float = 0.0

## 震动衰减速度（每秒衰减量）
var _decay: float = 3.0

## 每帧随机种子偏移
var _noise_offset: float = 0.0

## 震动最大偏移（像素）
var _max_offset: float = 10.0

## 原始相机位置
var _original_position: Vector2


# ============================================================
# 生命周期函数
# ============================================================

func _ready() -> void:
	var cam: Camera2D = get_parent() as Camera2D
	if cam:
		_original_position = cam.position
	else:
		_original_position = Vector2.ZERO


func _process(delta: float) -> void:
	if _trauma <= 0.001:
		_trauma = 0.0
		return

	# 衰减
	_trauma = maxf(_trauma - _decay * delta, 0.0)

	# 根据 trauma 值计算偏移
	var shake_amount: float = _trauma * _trauma  # 平方曲线，小震感更细腻
	var offset := Vector2(
		randf_range(-1.0, 1.0) * _max_offset * shake_amount,
		randf_range(-1.0, 1.0) * _max_offset * shake_amount
	)

	var cam: Camera2D = get_parent() as Camera2D
	if cam:
		cam.position = _original_position + offset


# ============================================================
# 公共接口
# ============================================================

func shake(intensity: float, duration: float = 0.3) -> void:
	## 触发相机震动
	## intensity: 0.0~1.0  1.0 = 最大偏移
	## duration: 持续时间（秒），越长衰减越慢
	_trauma = clampf(intensity, 0.0, 1.0)
	_decay = 1.0 / maxf(duration, 0.05)
