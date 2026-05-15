extends Area2D
## 经验球控制器
## 负责：被玩家吸引 / 碰触吸收 / 给予经验


# ============================================================
# 导出变量（可在编辑器中调整）
# ============================================================

## 经验值
@export var exp_value: int = 10

## 向玩家飞行的速度（像素/秒）
@export var move_speed: float = 250.0

## 吸引范围（像素），玩家进入此范围后开始飞向玩家
@export var attract_range: float = 100.0


# ============================================================
# 内部状态变量
# ============================================================

## 玩家引用
var _player: Node2D = null

## 是否已被吸引
var _attracted: bool = false

## 是否已提交延迟回收
var _pending_release: bool = false


# ============================================================
# 生命周期函数
# ============================================================

func _ready() -> void:
	# 连接信号：当玩家物理体进入经验球区域
	body_entered.connect(_on_body_entered)
	# 查找玩家
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0] as Node2D


func reset_state() -> void:
	## 重置经验球状态（由对象池 acquire 时调用）
	_attracted = false
	_pending_release = false
	_player = null
	# 重新查找玩家
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0] as Node2D


func _return_to_pool() -> void:
	## 延迟回收经验球（由 call_deferred 调用）
	ObjectPoolManager.release_exp_orb(self)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player):
		return

	var dist: float = global_position.distance_to(_player.global_position)

	# 进入吸引范围后开始追踪玩家
	if not _attracted and dist < attract_range:
		_attracted = true

	if _attracted:
		var dir: Vector2 = (_player.global_position - global_position).normalized()
		position += dir * move_speed * delta


# ============================================================
# 碰撞处理
# ============================================================

func _on_body_entered(body: Node2D) -> void:
	## 当玩家碰触到经验球时吸收
	if not body.is_in_group("player"):
		return

	# 通知玩家等级控制器获得经验
	var level_ctrl: Node = body.get_node_or_null("LevelController")
	if level_ctrl and level_ctrl.has_method("add_exp"):
		level_ctrl.add_exp(exp_value)
	else:
		push_warning("[ExpOrb] 玩家缺少 LevelController 节点，经验未被接收")

	if not _pending_release:
		_pending_release = true
		call_deferred("_return_to_pool")
