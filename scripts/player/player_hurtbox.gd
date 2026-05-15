extends Area2D
## 玩家受伤盒
## 负责：检测敌人碰撞 / 触发伤害 / 无敌时间管理 / 开局保护


# ============================================================
# 导出变量（可在编辑器中调整）
# ============================================================

## 无敌时间（秒），受伤后此时间内不会再次受伤
@export var invincibility_time: float = 0.5

## 开局保护时间（秒），防止首波敌人刷在脚底
@export var spawn_protection_time: float = 8.0


# ============================================================
# 内部状态变量
# ============================================================

## 是否可受到伤害（开局保护期间为 false）
var _can_take_damage: bool = false

## 无敌计时器
var _invincibility_timer: float = 0.0

## 玩家 Sprite2D 引用（用于受伤闪烁）
var _sprite: Sprite2D = null


# ============================================================
# 生命周期函数
# ============================================================

func _ready() -> void:
	_sprite = get_parent().get_node_or_null("Sprite2D") as Sprite2D
	print("[HurtBox] 受伤检测就绪，无敌时间: %.1fs  开局保护: %.1fs" % [invincibility_time, spawn_protection_time])


func _physics_process(delta: float) -> void:
	# 开局保护倒计时（优先级最高）
	if spawn_protection_time > 0.0:
		spawn_protection_time -= delta
		if spawn_protection_time <= 0.0:
			spawn_protection_time = 0.0
			_can_take_damage = true
			print("[HurtBox] 开局保护结束，现在可以受到伤害")
		return  # 保护期间跳过一切伤害检测

	# 受伤后无敌计时器
	if not _can_take_damage:
		_invincibility_timer -= delta
		if _invincibility_timer <= 0.0:
			_end_invincibility()

	# 可受伤时检测是否有敌人重叠
	if _can_take_damage:
		_check_enemy_overlap()


# ============================================================
# 碰撞检测
# ============================================================

func _check_enemy_overlap() -> void:
	## 检查当前重叠的物理体，对第一个敌人触发受伤
	var bodies: Array[Node2D] = get_overlapping_bodies()
	for body: Node2D in bodies:
		if body.is_in_group("enemy"):
			_take_hit_from(body)
			break  # 同一帧只触发一次受伤


func _take_hit_from(enemy: Node2D) -> void:
	## 从指定敌人处受到伤害
	# 诊断日志：输出敌人名称和位置，便于定位"开局掉血"问题
	print("[HurtBox] 碰撞到敌人: %s (位置: %s)" % [enemy.name, enemy.global_position])

	var damage: int = 10
	var attack_ctrl: Node = enemy.get_node_or_null("AttackController")
	if attack_ctrl and attack_ctrl.has_method("get_contact_damage"):
		damage = attack_ctrl.get_contact_damage()

	var health: Node = get_parent().get_node_or_null("HealthController")
	if health and health.has_method("take_damage"):
		health.take_damage(damage)

	_start_invincibility()

	# 相机震动
	var cam: Camera2D = get_parent().get_node_or_null("Camera2D")
	if cam:
		var shake: Node = cam.get_node_or_null("CameraShake")
		if shake and shake.has_method("shake"):
			shake.shake(0.5, 0.15)
	AudioManager.play_player_hurt()


# ============================================================
# 无敌系统
# ============================================================

func _start_invincibility() -> void:
	_can_take_damage = false
	_invincibility_timer = invincibility_time
	if _sprite:
		_sprite.modulate.a = 0.4


func _end_invincibility() -> void:
	_can_take_damage = true
	if _sprite:
		_sprite.modulate.a = 1.0


# ============================================================
# 公共接口
# ============================================================

func is_invincible() -> bool:
	return not _can_take_damage
