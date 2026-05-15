extends Node
## 对象池管理器（Autoload 单例）
## 负责：统一管理所有对象池 / 提供获取/回收快捷接口
## 禁止各处自行 instantiate() 或 queue_free()


# ============================================================
# 导出变量
# ============================================================

## 子弹池初始大小
@export var bullet_pool_size: int = 100

## 敌人池初始大小
@export var enemy_pool_size: int = 50

## 经验球池初始大小
@export var exp_orb_pool_size: int = 60


# ============================================================
# 内部状态变量
# ============================================================

## 子弹池
var bullet_pool: ObjectPool = null

## 敌人池
var enemy_pool: ObjectPool = null

## 经验球池
var exp_orb_pool: ObjectPool = null

## 伤害飘字池
var damage_text_pool: ObjectPool = null

## 死亡粒子池
var death_particle_pool: ObjectPool = null


# ============================================================
# 生命周期函数
# ============================================================

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("[ObjectPoolManager] 对象池管理器就绪")


# ============================================================
# 公共接口 —— 初始化
# ============================================================

func init_bullet_pool(scene: PackedScene) -> ObjectPool:
	## 初始化子弹池（由 PlayerAttack 调用）
	if bullet_pool:
		return bullet_pool

	bullet_pool = ObjectPool.new()
	bullet_pool.name = "BulletPool"
	add_child(bullet_pool)
	bullet_pool.setup(scene, bullet_pool_size, true, 500)
	print("[ObjectPoolManager] 子弹池已初始化 (size=%d)" % bullet_pool.get_total_size())
	return bullet_pool


func init_enemy_pool(scene: PackedScene) -> ObjectPool:
	## 初始化敌人池（由 EnemyManager 调用）
	if enemy_pool:
		return enemy_pool

	enemy_pool = ObjectPool.new()
	enemy_pool.name = "EnemyPool"
	add_child(enemy_pool)
	enemy_pool.setup(scene, enemy_pool_size, true, 300)
	print("[ObjectPoolManager] 敌人池已初始化 (size=%d)" % enemy_pool.get_total_size())
	return enemy_pool


func init_exp_orb_pool(scene: PackedScene) -> ObjectPool:
	## 初始化经验球池（由 EnemyManager 调用）
	if exp_orb_pool:
		return exp_orb_pool

	exp_orb_pool = ObjectPool.new()
	exp_orb_pool.name = "ExpOrbPool"
	add_child(exp_orb_pool)
	exp_orb_pool.setup(scene, exp_orb_pool_size, true, 300)
	print("[ObjectPoolManager] 经验球池已初始化 (size=%d)" % exp_orb_pool.get_total_size())
	return exp_orb_pool


# ============================================================
# 公共接口 —— 获取
# ============================================================

func acquire_bullet() -> Area2D:
	## 从子弹池获取一颗子弹
	if not bullet_pool:
		push_error("[ObjectPoolManager] 子弹池未初始化")
		return null
	var bullet: Area2D = bullet_pool.acquire() as Area2D
	if bullet and bullet.has_method("reset_state"):
		bullet.reset_state()
	return bullet


func acquire_enemy() -> CharacterBody2D:
	## 从敌人池获取一个敌人
	if not enemy_pool:
		push_error("[ObjectPoolManager] 敌人池未初始化")
		return null
	var enemy: CharacterBody2D = enemy_pool.acquire() as CharacterBody2D
	if enemy and enemy.has_method("reset_state"):
		enemy.reset_state()
	return enemy


func acquire_exp_orb() -> Area2D:
	## 从经验球池获取一个经验球
	if not exp_orb_pool:
		push_error("[ObjectPoolManager] 经验球池未初始化")
		return null
	var orb: Area2D = exp_orb_pool.acquire() as Area2D
	if orb and orb.has_method("reset_state"):
		orb.reset_state()
	return orb


# ============================================================
# 公共接口 —— 回收
# ============================================================

func release_bullet(bullet: Area2D) -> void:
	## 回收子弹
	if bullet_pool:
		bullet_pool.release(bullet)


func release_enemy(enemy: CharacterBody2D) -> void:
	## 回收敌人
	if enemy_pool:
		enemy_pool.release(enemy)


func release_exp_orb(orb: Area2D) -> void:
	## 回收经验球
	if exp_orb_pool:
		exp_orb_pool.release(orb)


func init_damage_text_pool(scene: PackedScene) -> ObjectPool:
	if damage_text_pool:
		return damage_text_pool
	damage_text_pool = ObjectPool.new()
	damage_text_pool.name = "DamageTextPool"
	add_child(damage_text_pool)
	damage_text_pool.setup(scene, 30, true, 100)
	return damage_text_pool


func acquire_damage_text() -> Label:
	if not damage_text_pool:
		return null
	var label: Label = damage_text_pool.acquire() as Label
	if label and label.has_method("reset_state"):
		label.reset_state()
	return label


func release_damage_text(label: Label) -> void:
	if damage_text_pool:
		damage_text_pool.release(label)


func init_death_particle_pool(scene: PackedScene) -> ObjectPool:
	if death_particle_pool:
		return death_particle_pool
	death_particle_pool = ObjectPool.new()
	death_particle_pool.name = "DeathParticlePool"
	add_child(death_particle_pool)
	death_particle_pool.setup(scene, 20, true, 60)
	return death_particle_pool


func acquire_death_particle() -> Node2D:
	if not death_particle_pool:
		return null
	var particle: Node2D = death_particle_pool.acquire() as Node2D
	if particle and particle.has_method("reset_state"):
		particle.reset_state()
	return particle


func release_death_particle(particle: Node2D) -> void:
	if death_particle_pool:
		death_particle_pool.release(particle)


# ============================================================
# 查询接口
# ============================================================

func get_bullet_stats() -> Dictionary:
	## 获取子弹池统计
	if not bullet_pool:
		return {}
	return {"total": bullet_pool.get_total_size(), "active": bullet_pool.get_active_count(), "available": bullet_pool.get_available_count()}


func get_enemy_stats() -> Dictionary:
	## 获取敌人池统计
	if not enemy_pool:
		return {}
	return {"total": enemy_pool.get_total_size(), "active": enemy_pool.get_active_count(), "available": enemy_pool.get_available_count()}


func get_exp_orb_stats() -> Dictionary:
	## 获取经验球池统计
	if not exp_orb_pool:
		return {}
	return {"total": exp_orb_pool.get_total_size(), "active": exp_orb_pool.get_active_count(), "available": exp_orb_pool.get_available_count()}
