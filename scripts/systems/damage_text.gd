extends Label
## 伤害飘字
## 负责：显示伤害数值 / 向上漂浮 / 淡出消失 / 自动回收


# ============================================================
# 导出变量（可在编辑器中调整）
# ============================================================

## 漂浮速度（像素/秒）
@export var float_speed: float = 60.0

## 显示时长（秒）
@export var lifetime: float = 0.8

## 随机水平偏移范围
@export var random_offset: float = 15.0


# ============================================================
# 内部状态变量
# ============================================================

var _timer: float = 0.0
var _velocity: Vector2 = Vector2.ZERO


# ============================================================
# 生命周期函数
# ============================================================

func _ready() -> void:
	_timer = lifetime
	# 随机轻微水平漂移
	_velocity = Vector2(randf_range(-random_offset, random_offset), -float_speed)
	# 初始放大效果
	scale = Vector2(1.3, 1.3)


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		ObjectPoolManager.release_damage_text(self) if _has_pool() else queue_free()
		return

	# 向上漂浮
	position += _velocity * delta
	# 淡出
	modulate.a = clampf(_timer / (lifetime * 0.3), 0.0, 1.0)
	# 缩小
	scale = scale.move_toward(Vector2(0.8, 0.8), delta)


func _has_pool() -> bool:
	return is_instance_valid(ObjectPoolManager) and ObjectPoolManager.has_method("release_damage_text")


# ============================================================
# 公共接口
# ============================================================

func setup(value: int, pos: Vector2, color: Color = Color.WHITE) -> void:
	## 设置飘字内容与位置
	text = str(value)
	global_position = pos
	modulate = color
	modulate.a = 1.0
	_timer = lifetime
	scale = Vector2(1.3, 1.3)


func reset_state() -> void:
	## 重置飘字状态（由对象池调用）
	text = ""
	modulate = Color.WHITE
	modulate.a = 1.0
	scale = Vector2.ONE
	_timer = 0.0
