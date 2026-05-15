extends Area2D
## 子弹控制器
## 负责：直线飞行 / 碰撞检测 / 命中造成伤害


# ============================================================
# 导出变量（可在编辑器中调整）
# ============================================================

## 飞行速度（像素/秒）
@export var speed: float = 500.0

## 造成伤害值
@export var damage: int = 10

## 最大存活时间（秒），超时自动销毁
@export var lifetime: float = 3.0


# ============================================================
# 内部状态变量
# ============================================================

## 飞行方向（归一化向量）
var _direction: Vector2 = Vector2.ZERO

## 存活计时器
var _alive_time: float = 0.0

## 防止同一颗子弹重复命中多个敌人
var _has_hit: bool = false

## 剩余穿透次数（>0 时命中敌人不销毁，每命中一个减 1）
var pierce_remaining: int = 0

## 是否已提交延迟回收（防止重复 release）
var _pending_release: bool = false


# ============================================================
# 生命周期函数
# ============================================================

func _ready() -> void:
	# 连接 body_entered 信号，检测与敌人的碰撞
	body_entered.connect(_on_hit)


func _physics_process(delta: float) -> void:
	# 沿方向飞行
	position += _direction * speed * delta

	# 超时自动回收（延迟到下一帧，避免物理回调中修改场景树）
	_alive_time += delta
	if _alive_time >= lifetime and not _pending_release:
		_pending_release = true
		call_deferred("_return_to_pool")


# ============================================================
# 公共接口
# ============================================================

func launch(direction: Vector2, bullet_speed: float = 500.0) -> void:
	## 设置飞行方向和速度（由攻击系统调用）
	speed = bullet_speed
	_direction = direction.normalized()
	rotation = _direction.angle()


func reset_state() -> void:
	## 重置子弹状态（由对象池 acquire 时调用）
	_has_hit = false
	pierce_remaining = 0
	_alive_time = 0.0
	_direction = Vector2.ZERO
	rotation = 0.0
	_pending_release = false
	speed = 500.0


func _return_to_pool() -> void:
	## 延迟回收子弹到对象池（由 call_deferred 调用，避免物理回调中修改场景树）
	ObjectPoolManager.release_bullet(self)


func _spawn_damage_text(value: int, pos: Vector2) -> void:
	## 生成伤害飘字
	var text: Label = ObjectPoolManager.acquire_damage_text()
	if not text:
		return
	text.reparent(get_tree().current_scene, false)
	text.setup(value, pos + Vector2(randf_range(-10, 10), -20), Color(1.0, 0.9, 0.3, 1.0))


# ============================================================
# 碰撞处理
# ============================================================

func _on_hit(body: Node2D) -> void:
	## 当子弹碰撞到物理体时调用
	# 防止同一颗子弹重复命中同一个敌人
	if _has_hit:
		return

	# 检查是否命中敌人
	if body.is_in_group("enemy"):
		# 调用敌人的生命值组件造成伤害
		var health_node: Node = body.get_node_or_null("Health")
		if health_node and health_node.has_method("take_damage"):
			health_node.take_damage(damage)
		else:
			body.queue_free()

		# --- 打击感反馈 ---
		# 受击闪白
		if body.has_method("hit_flash"):
			body.hit_flash()
		# 伤害飘字
		_spawn_damage_text(damage, body.global_position)
		# 命中音效
		AudioManager.play_hit()

		# 穿透判定：穿透次数 > 0 则继续飞行
		if pierce_remaining > 0:
			pierce_remaining -= 1
			# 不标记 _has_hit，允许命中下一个敌人
		elif not _pending_release:
			_has_hit = true
			_pending_release = true
			call_deferred("_return_to_pool")
