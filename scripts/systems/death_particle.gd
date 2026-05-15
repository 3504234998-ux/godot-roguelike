extends Node2D
## 死亡粒子特效
## 负责：敌人死亡时播放粒子爆发 / 自动回收


# ============================================================
# 导出变量（可在编辑器中调整）
# ============================================================

## 粒子数量
@export var particle_count: int = 8

## 粒子大小
@export var particle_size: float = 4.0

## 扩散速度（像素/秒）
@export var spread_speed: float = 120.0

## 存活时间（秒）
@export var lifetime: float = 0.5

## 粒子颜色
@export var particle_color: Color = Color(1.0, 0.3, 0.3, 1.0)


# ============================================================
# 内部状态变量
# ============================================================

var _timer: float = 0.0
var _particles: Array = []  # [{node, velocity}]
var _active: bool = false


# ============================================================
# 公共接口
# ============================================================

func play(spawn_pos: Vector2, color: Color = Color(1.0, 0.3, 0.3, 1.0)) -> void:
	## 播放粒子爆发
	global_position = spawn_pos
	particle_color = color
	_active = true
	_timer = lifetime
	_spawn_particles()
	show()


func _spawn_particles() -> void:
	## 生成粒子小方块
	# 清除旧粒子子节点
	for child in get_children():
		if child is ColorRect:
			child.queue_free()
	_particles.clear()

	for i in range(particle_count):
		var rect := ColorRect.new()
		rect.size = Vector2(particle_size, particle_size)
		rect.position = Vector2(-particle_size / 2.0, -particle_size / 2.0)
		rect.color = particle_color
		add_child(rect)

		var angle: float = deg_to_rad(360.0 * i / particle_count + randf_range(-20.0, 20.0))
		var vel := Vector2(cos(angle), sin(angle)) * spread_speed * randf_range(0.6, 1.4)
		_particles.append({"node": rect, "velocity": vel})


func _process(delta: float) -> void:
	if not _active:
		return

	_timer -= delta
	var fade: float = clampf(_timer / (lifetime * 0.4), 0.0, 1.0)

	for p in _particles:
		var rect: ColorRect = p["node"]
		rect.position += p["velocity"] * delta
		rect.modulate.a = fade
		rect.scale = Vector2(fade, fade)

	if _timer <= 0.0:
		_active = false
		hide()
		# 清理子节点
		for p in _particles:
			p["node"].queue_free()
		_particles.clear()
		# 回收
		_release()


func _release() -> void:
	if is_instance_valid(ObjectPoolManager) and ObjectPoolManager.has_method("release_death_particle"):
		ObjectPoolManager.release_death_particle(self)
	else:
		queue_free()


func reset_state() -> void:
	## 重置状态（由对象池调用）
	_active = false
	_timer = 0.0
	for p in _particles:
		if is_instance_valid(p["node"]):
			p["node"].queue_free()
	_particles.clear()
	hide()
