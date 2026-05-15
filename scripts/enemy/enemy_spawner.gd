extends Node2D
## 敌人生成器
## 负责：定时生成敌人 / 随机位置 / 数量递增


# ============================================================
# 导出变量（可在编辑器中调整）
# ============================================================

## 敌人场景（在编辑器中拖入 Enemy.tscn）
@export var enemy_scene: PackedScene

## 初始生成间隔（秒）
@export var spawn_interval: float = 2.0

## 最小生成间隔（秒），随难度提升逐渐缩短到此值
@export var min_spawn_interval: float = 0.5

## 每波间隔缩短量（秒）
@export var interval_decay: float = 0.1

## 每波额外生成数量
@export var extra_per_wave: int = 1

## 生成范围半径（玩家周围多大范围生成敌人）
@export var spawn_radius: float = 600.0

## 玩家最小安全距离（敌人生成位置距玩家的最小距离）
@export var safe_distance: float = 300.0

## 同时存在的最大敌人数量
@export var max_enemies: int = 50


# ============================================================
# 内部状态变量
# ============================================================

## 生成计时器
var _timer: float = 0.0

## 当前波次（0 开始）
var _wave: int = 0

## 当前场上敌人数量
var _current_enemy_count: int = 0


# ============================================================
# 生命周期函数
# ============================================================

func _ready() -> void:
	_timer = spawn_interval
	print("[EnemySpawner] 敌人生成器就绪，初始间隔: %.1fs" % spawn_interval)


func _process(delta: float) -> void:
	# 更新场上敌人计数
	_current_enemy_count = get_tree().get_nodes_in_group("enemy").size()

	# 如果已达到最大数量，不再生成
	if _current_enemy_count >= max_enemies:
		return

	# 计时器倒计时
	_timer -= delta
	if _timer <= 0.0:
		_spawn_enemy()
		# 进入下一波，缩短间隔
		_wave += 1
		var new_interval: float = maxf(spawn_interval - _wave * interval_decay, min_spawn_interval)
		_timer = new_interval


# ============================================================
# 敌人生成
# ============================================================

func _spawn_enemy() -> void:
	## 在当前波次中生成敌人
	if not enemy_scene:
		push_error("[EnemySpawner] 未设置 enemy_scene！请在编辑器中拖入 Enemy.tscn")
		return

	# 查找玩家位置
	var player: Node2D = _find_player()
	if not player:
		push_warning("[EnemySpawner] 未找到玩家节点，跳过生成")
		return

	# 本波生成数量（随波次递增）
	var spawn_count: int = 1 + _wave * extra_per_wave

	for i in range(spawn_count):
		if _current_enemy_count + i >= max_enemies:
			break

		var enemy: CharacterBody2D = enemy_scene.instantiate() as CharacterBody2D
		enemy.global_position = _get_spawn_position(player.global_position)
		add_child(enemy)


func _get_spawn_position(player_pos: Vector2) -> Vector2:
	## 在玩家周围随机生成一个位置（保证安全距离）
	var angle: float = randf_range(0.0, TAU)
	var distance: float = randf_range(safe_distance, spawn_radius)
	return player_pos + Vector2.RIGHT.rotated(angle) * distance


func _find_player() -> Node2D:
	## 查找场景中的玩家
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0] as Node2D
	return null


# ============================================================
# 公共接口
# ============================================================

func get_wave() -> int:
	## 获取当前波次数
	return _wave


func get_enemy_count() -> int:
	## 获取当前场上敌人数量
	return _current_enemy_count
