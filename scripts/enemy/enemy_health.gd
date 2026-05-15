extends Node
## 敌人生命值组件
## 负责：HP管理 / 受到伤害 / 死亡处理


# ============================================================
# 信号
# ============================================================

## 敌人死亡信号（供经验系统、UI 等监听）
signal enemy_died

## 血量变化信号（供血条 UI 更新）
signal health_changed(current_hp: int, max_hp: int)


# ============================================================
# 导出变量（可在编辑器中调整）
# ============================================================

## 最大生命值
@export var max_hp: int = 30

## 死亡时掉落的经验球场景（在编辑器中拖入 ExpOrb.tscn）
@export var exp_orb_scene: PackedScene

## 死亡时掉落的经验值（可被 DataManager 覆写）
@export var exp_value: int = 10


# ============================================================
# 内部状态变量
# ============================================================

## 当前生命值
var current_hp: int

## 是否已死亡（防止重复触发 _die）
var _is_dead: bool = false


# ============================================================
# 生命周期函数
# ============================================================

func _ready() -> void:
	current_hp = max_hp


# ============================================================
# 伤害系统
# ============================================================

func take_damage(amount: int) -> void:
	## 受到伤害（由子弹等攻击来源调用）
	if _is_dead:
		return
	current_hp -= amount
	health_changed.emit(current_hp, max_hp)
	print("[Enemy HP] 受到 %d 点伤害，剩余 HP: %d/%d" % [amount, current_hp, max_hp])

	if current_hp <= 0:
		_is_dead = true
		_die()


func _die() -> void:
	## 敌人死亡：生成经验球 → 发送信号 → 回收到对象池
	print("[Enemy HP] 敌人死亡")

	# 累加全局击杀计数（供 GameOverUI 统计）
	GameManager.add_kill()

	# 先记录敌人位置（回收后无法访问父节点）
	var spawn_pos: Vector2 = (get_parent() as Node2D).global_position
	# 延迟生成经验球，避免物理查询刷新期间修改场景树
	call_deferred("_spawn_exp_orb", spawn_pos)

	enemy_died.emit()

	# 死亡粒子特效（延迟生成，避免场景树刷新冲突）
	call_deferred("_spawn_death_particles", spawn_pos)

	# 死亡音效
	if get_parent().is_in_group("boss"):
		AudioManager.play_boss_death()
	else:
		AudioManager.play_enemy_death()

	# Boss 使用传统方式销毁（不进入敌人池）
	# 延迟回收敌人（避免物理回调中修改场景树导致递归）
	if get_parent().is_in_group("boss"):
		get_parent().queue_free()
	else:
		call_deferred("_release_to_enemy_pool")


func _spawn_death_particles(pos: Vector2) -> void:
	## 生成死亡粒子特效
	var particle: Node2D = ObjectPoolManager.acquire_death_particle()
	if not particle:
		return
	# 根据敌人类型选择粒子颜色
	var p_color: Color = Color(1.0, 0.3, 0.3, 1.0)  # 默认红色
	if get_parent().is_in_group("boss"):
		p_color = Color(1.0, 0.7, 0.1, 1.0)  # Boss 金色
	elif get_parent().is_in_group("elite"):
		p_color = Color(1.0, 0.4, 0.1, 1.0)  # 精英橙色

	particle.reparent(get_tree().current_scene, false)
	particle.play(pos, p_color)


func _spawn_exp_orb(spawn_pos: Vector2) -> void:
	## 在指定位置生成经验球（由 _die 通过 call_deferred 调用）
	var orb: Area2D = ObjectPoolManager.acquire_exp_orb()
	if not orb:
		return

	orb.reparent(get_tree().current_scene, false)
	orb.global_position = spawn_pos
	# 使用当前敌人的经验值覆写经验球的默认值
	orb.exp_value = exp_value


# ============================================================
# 公共接口
# ============================================================

func get_hp_ratio() -> float:
	## 获取当前血量比例 [0.0, 1.0]，供血条 UI 使用
	return clampf(float(current_hp) / float(max_hp), 0.0, 1.0)


func _release_to_enemy_pool() -> void:
	## 延迟回收敌人到对象池（由 call_deferred 调用）
	ObjectPoolManager.release_enemy(get_parent() as CharacterBody2D)


func reset_state() -> void:
	## 重置血量状态（由对象池 acquire 时调用）
	_is_dead = false
	current_hp = max_hp


func is_alive() -> bool:
	## 检查是否存活
	return current_hp > 0 and not _is_dead
