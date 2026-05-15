extends Node2D
## EnemyManager — 敌人管理器
## 负责：定时刷怪 / 屏幕外出生 / 波次成长 / 数量限制
## 所有刷怪逻辑由 Timer 驱动，禁止 _process 轮询


# ============================================================
# 信号
# ============================================================

## 波次变化（供 UI 显示当前波次）
signal wave_changed(wave: int)

## 敌人被生成（供对象池、音效等系统监听）
signal enemy_spawned(enemy: Node2D)

## 场上敌人数量变化（供 UI 显示怪物数量）
signal enemy_count_changed(current: int, maximum: int)

## 达到最大敌人数上限
signal max_enemies_reached


# ============================================================
# 导出变量（可在编辑器中调整）
# ============================================================

## 敌人场景（在编辑器中拖入 Enemy.tscn）
@export var enemy_scene: PackedScene

## 敌人类型ID（对应 enemy_data.json 中的 key，作为回退选项）
@export var enemy_type: String = "basic_enemy"

## 是否启用波次加权刷怪（关闭时固定使用 enemy_type）
@export var use_wave_weights: bool = true

## 初始刷怪间隔（秒）
@export var spawn_interval: float = 2.0

## 最短刷怪间隔（秒），波次提升后不会低于此值
@export var min_spawn_interval: float = 0.3

## 每波间隔缩减量（秒）
@export var interval_decay: float = 0.15

## 每次刷怪基础数量
@export var spawn_count_base: int = 1

## 每波额外增加刷怪数量
@export var spawn_count_per_wave: int = 1

## 波次持续时长（秒），每过此时间波次+1
@export var wave_duration: float = 30.0

## 同时存在的最大敌人数量
@export var max_enemies: int = 100

## 屏幕外生成边距（像素），确保敌人在屏幕外生成
@export var spawn_margin: float = 100.0

## 生成位置随机抖动范围（像素），避免敌人排成直线
@export var spawn_jitter: float = 40.0

## Boss 场景（在编辑器中拖入 Boss.tscn）
@export var boss_scene: PackedScene

## Boss 生成时间（秒），从游戏开始计时
@export var boss_spawn_time: float = 300.0

## 伤害飘字场景
@export var damage_text_scene: PackedScene

## 死亡粒子场景
@export var death_particle_scene: PackedScene


# ============================================================
# 内部状态变量
# ============================================================

## 游戏启动时的毫秒时间戳
var _start_time: int = 0

## 当前波次（从 1 开始）
var _current_wave: int = 1

## 上一帧检查时的波次（用于检测波次变化）
var _last_wave: int = 1

## 玩家是否已死亡（死亡后停止刷怪）
var _player_dead: bool = false

## Boss 是否已生成（防止重复生成）
var _boss_spawned: bool = false

## Boss 是否存活
var _boss_alive: bool = false

## Boss 存在期间暂停的普通刷怪定时器等待时间缓存
var _cached_spawn_interval: float = 0.0


# ============================================================
# 节点引用
# ============================================================

@onready var _spawn_timer: Timer = $SpawnTimer


# ============================================================
# 生命周期函数
# ============================================================

func _ready() -> void:
	add_to_group("enemy_manager")
	# 记录游戏启动时间（毫秒）
	_start_time = Time.get_ticks_msec()

	# 初始化对象池
	call_deferred("_init_pools")

	# 配置刷怪定时器
	_spawn_timer.one_shot = false
	_spawn_timer.wait_time = spawn_interval
	_spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	_spawn_timer.start()

	# 延迟连接玩家死亡信号（等待场景中所有节点就绪）
	call_deferred("_connect_player_death_signal")

	print("[EnemyManager] 就绪 — 初始间隔: %.1fs  波次时长: %.0fs  最大敌人数: %d" % [spawn_interval, wave_duration, max_enemies])


func _init_pools() -> void:
	## 初始化所有对象池（敌人、经验球、飘字、粒子）
	if enemy_scene:
		ObjectPoolManager.init_enemy_pool(enemy_scene)

	# 查找经验球场景（从敌人实例获取 exp_orb_scene 引用）
	var sample_enemy: CharacterBody2D = enemy_scene.instantiate() as CharacterBody2D
	var health: Node = sample_enemy.get_node_or_null("Health")
	if health and health.get("exp_orb_scene"):
		ObjectPoolManager.init_exp_orb_pool(health.exp_orb_scene)
	sample_enemy.queue_free()

	# 初始化特效池
	if damage_text_scene:
		ObjectPoolManager.init_damage_text_pool(damage_text_scene)
	if death_particle_scene:
		ObjectPoolManager.init_death_particle_pool(death_particle_scene)


# ============================================================
# 定时器回调（唯一刷怪入口）
# ============================================================

func _on_spawn_timer_timeout() -> void:
	## SpawnTimer 超时回调：计算当前波次 → 更新刷怪参数 → 执行刷怪
	# 从游戏总时长计算当前波次
	_update_wave()

	# 检查 Boss 生成条件
	if not _boss_spawned:
		_check_boss_spawn()

	# Boss 存活期间暂停普通刷怪
	if _boss_alive:
		return

	# 根据当前波次计算本次刷怪参数
	var count: int = _get_spawn_count()
	var interval: float = _get_spawn_interval()

	# 更新定时器间隔（动态调整刷怪频率）
	_spawn_timer.wait_time = interval

	# 执行刷怪
	for i in range(count):
		if _get_enemy_count() >= max_enemies:
			max_enemies_reached.emit()
			break
		_spawn_single()


# ============================================================
# 波次管理
# ============================================================

func _update_wave() -> void:
	## 根据游戏已运行时间更新波次
	var elapsed: float = (Time.get_ticks_msec() - _start_time) / 1000.0
	_current_wave = maxi(int(elapsed / wave_duration) + 1, 1)

	if _current_wave != _last_wave:
		_last_wave = _current_wave
		wave_changed.emit(_current_wave)
		print("[EnemyManager] ★ 进入第 %d 波！ 刷怪间隔: %.2fs  每次数量: %d" % [_current_wave, _get_spawn_interval(), _get_spawn_count()])


func _get_spawn_interval() -> float:
	## 根据当前波次计算刷怪间隔
	return maxf(spawn_interval - (_current_wave - 1) * interval_decay, min_spawn_interval)


func _get_spawn_count() -> int:
	## 根据当前波次计算每次刷怪数量
	return spawn_count_base + (_current_wave - 1) * spawn_count_per_wave


# ============================================================
# 敌人生成
# ============================================================

func _connect_player_death_signal() -> void:
	## 查找玩家并连接死亡信号（玩家死亡后停止刷怪）
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return

	var player: Node = players[0]
	var health: Node = player.get_node_or_null("HealthController")
	if health and health.has_signal("player_died"):
		health.player_died.connect(_on_player_died)


func _on_player_died() -> void:
	## 玩家死亡回调：停止刷怪定时器
	_player_dead = true
	_spawn_timer.stop()
	print("[EnemyManager] 玩家已死亡，停止刷怪")


func _spawn_single() -> void:
	## 生成单个敌人
	if _player_dead:
		return
	if not enemy_scene:
		push_error("[EnemyManager] 未设置 enemy_scene！请在编辑器中拖入 Enemy.tscn")
		return

	var player_pos: Vector2 = _find_player_position()
	if player_pos == Vector2.INF:
		return  # 玩家不存在时静默跳过（不刷日志）

	# ① 根据波次权重选择敌人类型
	var picked_type: String = _pick_enemy_type()

	# ② 从对象池获取敌人
	var enemy: CharacterBody2D = ObjectPoolManager.acquire_enemy()
	if not enemy:
		return
	enemy.global_position = _get_screen_edge_position(player_pos)

	# ③ 从 DataManager 读取敌人配置并应用波次缩放
	if DataManager.is_loaded() and DataManager.has_enemy_type(picked_type):
		var data: Dictionary = DataManager.get_enemy_data(picked_type)
		_apply_wave_scaling(data, picked_type)
		if enemy.has_method("configure"):
			enemy.configure(data)

	enemy.reparent(self, false)

	enemy_spawned.emit(enemy)
	enemy_count_changed.emit(_get_enemy_count(), max_enemies)


func _pick_enemy_type() -> String:
	## 根据当前波次和权重表随机选择敌人类型
	if not use_wave_weights or not DataManager.is_loaded():
		return enemy_type

	var weights: Dictionary = DataManager.get_wave_spawn_weights(_current_wave)
	if weights.is_empty():
		return enemy_type

	var picked: String = _weighted_random(weights)
	if picked.is_empty():
		return enemy_type
	return picked


# ============================================================
# Boss 生成
# ============================================================

func _check_boss_spawn() -> void:
	## 检查是否满足 Boss 生成条件
	if not boss_scene:
		return
	if get_time_elapsed() < boss_spawn_time:
		return

	_spawn_boss()


func _spawn_boss() -> void:
	## 生成 Boss：显示警报 → 暂停刷怪 → 生成 Boss
	_boss_spawned = true
	_boss_alive = true

	# 暂停普通刷怪
	_cached_spawn_interval = _spawn_timer.wait_time
	_spawn_timer.stop()

	# 显示 Boss 警报
	var alerts := get_tree().get_nodes_in_group("boss_alert")
	if not alerts.is_empty():
		var alert: CanvasLayer = alerts[0] as CanvasLayer
		if alert.has_method("show_alert"):
			alert.show_alert()

	# 延迟 0.3 秒后生成 Boss（给警报一点显示时间）
	await get_tree().create_timer(0.3).timeout

	if _player_dead:
		return

	var player_pos: Vector2 = _find_player_position()
	if player_pos == Vector2.INF:
		return

	var boss: CharacterBody2D = boss_scene.instantiate() as CharacterBody2D
	boss.global_position = _get_screen_edge_position(player_pos)

	# 从 DataManager 读取 Boss 配置
	if DataManager.is_loaded() and DataManager.has_enemy_type("boss"):
		var data: Dictionary = DataManager.get_enemy_data("boss")
		if boss.has_method("configure"):
			boss.configure(data)

	add_child(boss)
	enemy_spawned.emit(boss)

	# 绑定 Boss 血条 UI
	var hp_bars := get_tree().get_nodes_in_group("boss_hp_bar")
	if not hp_bars.is_empty():
		var hp_bar = hp_bars[0]
		if hp_bar.has_method("bind_boss"):
			hp_bar.bind_boss(boss, "BOSS 冲撞者")

	# 连接 Boss 死亡信号
	var health: Node = boss.get_node_or_null("Health")
	if health and health.has_signal("enemy_died"):
		health.enemy_died.connect(_on_boss_died)

	print("[EnemyManager] Boss 已生成！HP: 3000  Speed: 60  DashSpeed: 300")


func _on_boss_died() -> void:
	## Boss 死亡回调：恢复普通刷怪
	_boss_alive = false
	_spawn_timer.wait_time = _cached_spawn_interval
	_spawn_timer.start()

	# 隐藏 Boss 血条
	var hp_bars := get_tree().get_nodes_in_group("boss_hp_bar")
	if not hp_bars.is_empty():
		var hp_bar = hp_bars[0]
		if hp_bar.has_method("unbind"):
			hp_bar.unbind()

	print("[EnemyManager] Boss 已死亡！恢复普通刷怪")


func _apply_wave_scaling(data: Dictionary, _enemy_type: String) -> void:
	## 根据当前波次缩放敌人属性
	## 公式: scaled = base * (1 + multiplier * (wave - 1))
	if not data.has("hp"):
		return

	if data.has("hp") and typeof(data["hp"]) == TYPE_INT:
		data["hp"] = int(float(data["hp"]) * DataManager.get_enemy_wave_scaling(_current_wave, "hp"))
	if data.has("damage") and typeof(data["damage"]) == TYPE_INT:
		data["damage"] = int(float(data["damage"]) * DataManager.get_enemy_wave_scaling(_current_wave, "damage"))
	if data.has("speed") and typeof(data["speed"]) == TYPE_INT:
		data["speed"] = int(float(data["speed"]) * DataManager.get_enemy_wave_scaling(_current_wave, "speed"))
	if data.has("exp_value") and typeof(data["exp_value"]) == TYPE_INT:
		data["exp_value"] = int(float(data["exp_value"]) * DataManager.get_enemy_wave_scaling(_current_wave, "exp"))


func _weighted_random(weights: Dictionary) -> String:
	## 加权随机算法：根据权重字典随机选取一个 key
	var total: int = 0
	for weight in weights.values():
		total += int(weight)

	if total <= 0:
		return ""

	var roll: int = randi() % total
	var cumulative: int = 0
	for key in weights.keys():
		cumulative += int(weights[key])
		if roll < cumulative:
			return key
	return ""


# ============================================================
# 屏幕外随机出生算法
# ============================================================

func _get_screen_edge_position(player_pos: Vector2) -> Vector2:
	## 在玩家屏幕外围随机生成一个位置
	## 算法：取视口矩形 → 向外扩展 margin → 在四条边上随机选点
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size

	# 视口半尺寸 + 额外边距 = 敌人出生边框
	var half_w: float = viewport_size.x / 2.0 + spawn_margin
	var half_h: float = viewport_size.y / 2.0 + spawn_margin

	# 随机选择一条边：0=上 1=下 2=左 3=右
	var edge: int = randi() % 4
	var offset: Vector2

	match edge:
		0: # 上边
			offset = Vector2(randf_range(-half_w, half_w), -half_h)
		1: # 下边
			offset = Vector2(randf_range(-half_w, half_w), half_h)
		2: # 左边
			offset = Vector2(-half_w, randf_range(-half_h, half_h))
		3: # 右边
			offset = Vector2(half_w, randf_range(-half_h, half_h))

	# 加入随机抖动，避免敌人排成直线
	offset += Vector2(randf_range(-spawn_jitter, spawn_jitter), randf_range(-spawn_jitter, spawn_jitter))

	return player_pos + offset


# ============================================================
# 查询工具
# ============================================================

func _find_player_position() -> Vector2:
	## 查找场景中玩家的位置
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return Vector2.INF
	return (players[0] as Node2D).global_position


func _get_enemy_count() -> int:
	## 获取当前场上活跃敌人数量（排除对象池中未激活的）
	var count: int = 0
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy.process_mode != Node.PROCESS_MODE_DISABLED:
			count += 1
	return count


# ============================================================
# 公共接口（供 UI / GameManager 调用）
# ============================================================

func get_wave() -> int:
	## 获取当前波次
	return _current_wave


func get_enemy_count() -> int:
	## 获取当前场上敌人数量
	return _get_enemy_count()


func get_time_elapsed() -> float:
	## 获取游戏已运行时间（秒）
	return (Time.get_ticks_msec() - _start_time) / 1000.0


func force_spawn(count: int = 1) -> void:
	## 强制立即生成指定数量的敌人（用于 Boss 登场等特殊事件）
	for i in range(count):
		if _get_enemy_count() >= max_enemies:
			break
		_spawn_single()


func set_spawn_paused(paused: bool) -> void:
	## 暂停/恢复刷怪
	if paused:
		_spawn_timer.stop()
	else:
		_spawn_timer.start()
