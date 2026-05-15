extends CharacterBody2D
## Boss 冲撞控制器
## 负责：追踪玩家 / 冲刺技能 / 状态机切换
## 复用 Health 和 AttackController 子节点


# ============================================================
# 常量
# ============================================================

## Boss AI 状态枚举
enum BossState {
	CHASE,         # 缓慢追踪玩家
	DASH_PREPARE,  # 冲刺蓄力（闪烁提示）
	DASH,          # 高速冲刺中
	COOLDOWN,      # 冲刺后冷却
}


# ============================================================
# 导出变量（可在编辑器中调整）
# ============================================================

## 追踪移动速度（像素/秒）
@export var move_speed: float = 60.0

## 冲刺速度（像素/秒）
@export var dash_speed: float = 300.0

## 冲刺持续时间（秒）
@export var dash_duration: float = 0.5

## 冲刺冷却时间（秒）
@export var dash_cooldown: float = 4.0

## 冲刺蓄力时间（秒），期间 Boss 闪烁
@export var dash_prepare_time: float = 0.8

## 触发冲刺的最小距离（像素），太近时不会冲刺
@export var dash_range_min: float = 80.0

## 停止追踪的距离（像素）
@export var stop_distance: float = 12.0


# ============================================================
# 内部状态变量
# ============================================================

## 当前 AI 状态
var _state: BossState = BossState.CHASE

## 状态计时器
var _state_timer: float = 0.0

## 冲刺方向（归一化）
var _dash_direction: Vector2 = Vector2.ZERO

## 玩家引用（缓存）
var _player: CharacterBody2D = null

## 精灵引用
@onready var _sprite: Sprite2D = $Sprite2D


# ============================================================
# 生命周期函数
# ============================================================

func _ready() -> void:
	add_to_group("enemy")
	add_to_group("boss")
	call_deferred("_find_player")
	print("[Boss] Boss 就绪 — HP:%s  Speed:%.0f  DashSpeed:%.0f" % [
		_get_hp(), move_speed, dash_speed
	])


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player):
		_find_player()
		return

	_state_timer -= delta

	match _state:
		BossState.CHASE:
			_process_chase(delta)
		BossState.DASH_PREPARE:
			_process_dash_prepare(delta)
		BossState.DASH:
			_process_dash(delta)
		BossState.COOLDOWN:
			_process_cooldown(delta)


# ============================================================
# CHASE 状态：缓慢追踪玩家
# ============================================================

func _process_chase(_delta: float) -> void:
	var to_player: Vector2 = _player.global_position - global_position
	var distance: float = to_player.length()

	# 停止距离内不动
	if distance < stop_distance:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var direction: Vector2 = to_player.normalized()
	velocity = direction * move_speed
	move_and_slide()
	_face_direction(direction)

	# 冲刺条件：距离足够远 + 冷却结束
	if distance > dash_range_min:
		_enter_state(BossState.DASH_PREPARE)


# ============================================================
# DASH_PREPARE 状态：蓄力闪烁
# ============================================================

func _enter_dash_prepare() -> void:
	# 记录冲刺方向（指向玩家当前位置）
	_dash_direction = (_player.global_position - global_position).normalized()
	if _dash_direction == Vector2.ZERO:
		_dash_direction = Vector2.RIGHT


func _process_dash_prepare(_delta: float) -> void:
	# 蓄力期间闪烁（每 0.1 秒切换可见性）
	if _sprite:
		_sprite.visible = fmod(Time.get_ticks_msec() / 100.0, 2.0) >= 1.0

	# 蓄力结束 → 冲刺
	if _state_timer <= 0.0:
		_enter_state(BossState.DASH)


# ============================================================
# DASH 状态：高速冲刺
# ============================================================

func _enter_dash() -> void:
	if _sprite:
		_sprite.visible = true
	# 屏幕震动
	_trigger_camera_shake()
	AudioManager.play_boss_dash()


func _process_dash(_delta: float) -> void:
	velocity = _dash_direction * dash_speed
	move_and_slide()

	# 冲刺结束 → 进入冷却
	if _state_timer <= 0.0:
		_enter_state(BossState.COOLDOWN)


# ============================================================
# COOLDOWN 状态：冲刺后短暂休息
# ============================================================

func _process_cooldown(_delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, move_speed * 2.0 * _delta)
	move_and_slide()

	if _state_timer <= 0.0:
		_enter_state(BossState.CHASE)


# ============================================================
# 状态机辅助
# ============================================================

func _enter_state(new_state: BossState) -> void:
	_state = new_state

	match new_state:
		BossState.CHASE:
			pass
		BossState.DASH_PREPARE:
			_state_timer = dash_prepare_time
			_enter_dash_prepare()
		BossState.DASH:
			_state_timer = dash_duration
			_enter_dash()
		BossState.COOLDOWN:
			_state_timer = dash_cooldown


# ============================================================
# 视觉朝向
# ============================================================

func _face_direction(direction: Vector2) -> void:
	if _sprite:
		_sprite.rotation = direction.angle()


# ============================================================
# 玩家查找
# ============================================================

func _find_player() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0] as CharacterBody2D


# ============================================================
# 数据配置（由 EnemyManager 注入）
# ============================================================

func configure(data: Dictionary) -> void:
	## 根据数据字典配置 Boss 属性
	if data.has("speed"):
		move_speed = data["speed"]
	if data.has("hp"):
		var health: Node = get_node_or_null("Health")
		if health:
			health.max_hp = data["hp"]
			health.current_hp = data["hp"]
	if data.has("damage"):
		var attack: Node = get_node_or_null("AttackController")
		if attack:
			attack.contact_damage = data["damage"]
	if data.has("exp_value"):
		var health: Node = get_node_or_null("Health")
		if health:
			health.set("exp_value", data["exp_value"])
	if data.has("sprite_path"):
		if _sprite and ResourceLoader.exists(data["sprite_path"]):
			_sprite.texture = load(data["sprite_path"])
		elif _sprite and data.has("color"):
			_sprite.modulate = Color(data["color"]["r"], data["color"]["g"], data["color"]["b"], data["color"].get("a", 1.0))
	elif data.has("color") and _sprite:
		_sprite.modulate = Color(data["color"]["r"], data["color"]["g"], data["color"]["b"], data["color"].get("a", 1.0))

	if data.has("scale"):
		scale = Vector2(data["scale"], data["scale"])


# ============================================================
# 内部查询
# ============================================================

func _get_hp() -> int:
	var health: Node = get_node_or_null("Health")
	if health:
		return health.max_hp
	return 0


func _trigger_camera_shake() -> void:
	## 触发全局相机震动
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var cam: Camera2D = players[0].get_node_or_null("Camera2D")
	if cam:
		var shake: Node = cam.get_node_or_null("CameraShake")
		if shake and shake.has_method("shake"):
			shake.shake(0.8, 0.3)
