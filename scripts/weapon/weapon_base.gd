class_name WeaponBase
extends Node2D
## 武器基类
## 负责：冷却计时 / 子弹生成 / 属性存储 / 升级接口
## 子类重写 fire() 实现不同攻击模式


# ============================================================
# 信号
# ============================================================

signal fired(weapon_id: String)


# ============================================================
# 武器属性（由 setup 从 weapon_data.json 填充）
# ============================================================

var weapon_id: String = ""
var weapon_name: String = ""
var damage: int = 10
var fire_rate: float = 2.0
var bullet_count: int = 1
var spread_angle: float = 5.0
var pierce_count: int = 0
var bullet_speed: float = 500.0
var description: String = ""


# ============================================================
# 内部状态变量
# ============================================================

## 冷却剩余时间（秒），<= 0 时可射击
var _cooldown: float = 0.0

## WeaponPivot 引用（由 WeaponManager 注入）
var _weapon_pivot: Node2D = null

## 子弹场景（由 WeaponManager 注入）
var _bullet_scene: PackedScene = null


# ============================================================
# 配置
# ============================================================

func setup(config: Dictionary, pivot: Node2D, bullet_scene: PackedScene) -> void:
	## 从数据字典加载武器属性
	weapon_id = config.get("id", "")
	weapon_name = config.get("name", "")
	damage = config.get("damage", 10)
	fire_rate = config.get("fire_rate", 2.0)
	bullet_count = config.get("bullet_count", 1)
	spread_angle = config.get("spread_angle", 5.0)
	pierce_count = config.get("pierce_count", 0)
	bullet_speed = config.get("bullet_speed", 500.0)
	description = config.get("description", "")

	_weapon_pivot = pivot
	_bullet_scene = bullet_scene
	_cooldown = 0.0

	print("[WeaponBase] %s 已装备 — 伤害:%d 射速:%.1f/s 弹数:%d" % [weapon_name, damage, fire_rate, bullet_count])


# ============================================================
# 每帧更新
# ============================================================

func update_cooldown(delta: float) -> void:
	## 推进冷却计时（由 WeaponManager._process 调用）
	if _cooldown > 0.0:
		_cooldown -= delta


func try_fire() -> void:
	## 尝试射击（冷却完毕且瞄准方向有效时调用）
	if _cooldown > 0.0:
		return
	if not _weapon_pivot or not _bullet_scene:
		return

	var aim_dir: Vector2 = _get_aim_direction()
	if aim_dir == Vector2.ZERO:
		return

	# 重置冷却（fire_rate 越大冷却越短）
	_cooldown = 1.0 / maxf(fire_rate, 0.1)

	fire(aim_dir)
	fired.emit(weapon_id)


# ============================================================
# 射击逻辑（子类重写此方法实现不同武器行为）
# ============================================================

func fire(aim_dir: Vector2) -> void:
	## 默认单发实现，子类应重写
	_spawn_bullet(aim_dir, _get_muzzle_position(), damage, pierce_count, bullet_speed)


# ============================================================
# 工具方法
# ============================================================

func _get_aim_direction() -> Vector2:
	## 获取当前瞄准方向
	if _weapon_pivot and _weapon_pivot.has_method("get_aim_direction"):
		return _weapon_pivot.get_aim_direction()
	return Vector2.RIGHT


func _get_muzzle_position() -> Vector2:
	## 获取枪口全局位置
	if _weapon_pivot and _weapon_pivot.has_method("get_muzzle_position"):
		return _weapon_pivot.get_muzzle_position()
	return global_position


func _spawn_bullet(direction: Vector2, spawn_pos: Vector2, dmg: int, pierce: int, speed: float) -> void:
	## 生成一颗子弹（使用对象池）
	var bullet: Area2D = ObjectPoolManager.acquire_bullet()
	if not bullet:
		return

	bullet.reparent(get_tree().current_scene, false)
	bullet.global_position = spawn_pos
	bullet.damage = dmg
	bullet.pierce_remaining = pierce
	bullet.launch(direction, speed)


func _spawn_spread(direction: Vector2, spawn_pos: Vector2, count: int, spread: float, dmg: int, pierce: int, speed: float) -> void:
	## 生成多颗散布子弹
	var total_spread: float = spread * float(count - 1)
	var start_angle: float = -total_spread / 2.0

	for i in range(count):
		var dir: Vector2 = direction
		if count > 1:
			var offset_deg: float = start_angle + spread * float(i)
			dir = direction.rotated(deg_to_rad(offset_deg))
		_spawn_bullet(dir, spawn_pos, dmg, pierce, speed)


# ============================================================
# 升级接口
# ============================================================

func upgrade_damage(amount: int) -> void:
	damage += amount


func upgrade_fire_rate(multiplier: float) -> void:
	fire_rate *= multiplier


func upgrade_bullet_count(amount: int) -> void:
	bullet_count = maxi(bullet_count + amount, 1)


func upgrade_pierce(amount: int) -> void:
	pierce_count = maxi(pierce_count + amount, 0)


func upgrade_bullet_speed(multiplier: float) -> void:
	bullet_speed *= multiplier
