extends Node
## 玩家攻击控制器
## 负责：定时沿瞄准方向发射子弹 / 散布控制 / 对象池管理


# ============================================================
# 导出变量（可在编辑器中调整）
# ============================================================

## 子弹场景（在编辑器中拖入 Bullet.tscn）
@export var bullet_scene: PackedScene

## 攻击间隔（秒）
@export var attack_interval: float = 0.5


# ============================================================
# 内部状态变量
# ============================================================

## 当前子弹伤害（可被升级系统提升）
var current_damage: int = 10

## 每次攻击发射的子弹数量
var bullet_count: int = 1

## 子弹穿透次数（0 = 命中即销毁）
var pierce_count: int = 0

## 多子弹散布角度（度）
var spread_angle: float = 5.0

## 当前子弹飞行速度（可被升级系统提升）
var current_bullet_speed: float = 500.0

## 攻击计时器（倒计时）
var _timer: float = 0.0

## WeaponPivot 节点引用
var _weapon_pivot: Node2D = null


# ============================================================
# 生命周期函数
# ============================================================

func _ready() -> void:
	_timer = 0.0
	if bullet_scene:
		ObjectPoolManager.init_bullet_pool(bullet_scene)

	# 缓存 WeaponPivot 引用
	_weapon_pivot = get_parent().get_node_or_null("WeaponPivot")
	if not _weapon_pivot:
		push_error("[PlayerAttack] 未找到 WeaponPivot 节点！请在 Player 下添加 WeaponPivot")

	print("[PlayerAttack] 朝向射击系统就绪，间隔: %.1fs  子弹数: %d  穿透: %d" % [attack_interval, bullet_count, pierce_count])


func _process(delta: float) -> void:
	# 攻击计时器倒计时
	_timer -= delta
	if _timer <= 0.0:
		_timer = attack_interval
		_try_attack()


# ============================================================
# 攻击执行
# ============================================================

func _try_attack() -> void:
	## 沿瞄准方向发射子弹
	if not bullet_scene:
		return
	if not _weapon_pivot:
		return

	# 从 WeaponPivot 获取瞄准方向和枪口位置
	var aim_dir: Vector2 = _weapon_pivot.get_aim_direction()
	var muzzle_pos: Vector2 = _weapon_pivot.get_muzzle_position()

	if aim_dir == Vector2.ZERO:
		return

	_fire_bullet(aim_dir, muzzle_pos)


func _fire_bullet(base_direction: Vector2, spawn_pos: Vector2) -> void:
	## 沿指定方向发射子弹（支持多发散布）
	var count: int = maxi(bullet_count, 1)
	var total_spread: float = spread_angle * float(count - 1)
	var start_angle: float = -total_spread / 2.0

	for i in range(count):
		var dir: Vector2 = base_direction
		if count > 1:
			var offset_deg: float = start_angle + spread_angle * float(i)
			var offset_rad: float = deg_to_rad(offset_deg)
			dir = base_direction.rotated(offset_rad)

		var bullet: Area2D = ObjectPoolManager.acquire_bullet()
		if not bullet:
			continue

		bullet.reparent(get_tree().current_scene, false)
		bullet.global_position = spawn_pos
		bullet.damage = current_damage
		bullet.pierce_remaining = pierce_count

		bullet.launch(dir, current_bullet_speed)


# ============================================================
# 公共接口
# ============================================================

func set_attack_interval(interval: float) -> void:
	## 动态设置攻击间隔（用于升级系统）
	attack_interval = maxf(interval, 0.1)


func increase_damage(amount: int) -> void:
	## 增加子弹伤害（由等级系统调用）
	current_damage += amount
	print("[PlayerAttack] 子弹伤害提升至: %d" % current_damage)
