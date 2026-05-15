extends CharacterBody2D
## 玩家移动控制器
## 负责：WASD移动 / 鼠标朝向 / 空格冲刺


# ============================================================
# 常量
# ============================================================

## 冲刺冷却时间（秒）
const DASH_COOLDOWN: float = 1.0

## 冲刺持续时间（秒）
const DASH_DURATION: float = 0.15


# ============================================================
# 导出变量（可在编辑器中调整）
# ============================================================

## 常规移动速度（像素/秒）
@export var move_speed: float = 250.0

## 冲刺速度（像素/秒）
@export var dash_speed: float = 800.0


# ============================================================
# 内部状态变量
# ============================================================

## 当前是否正在冲刺
var is_dashing: bool = false

## 冲刺冷却剩余时间（<= 0 表示冷却完毕）
var dash_cooldown_left: float = 0.0

## 本次冲刺剩余时间
var dash_time_left: float = 0.0

## 冲刺方向（归一化向量）
var dash_direction: Vector2 = Vector2.ZERO

## 手动追踪按键状态（通过 _input 维持）
var _keys: Dictionary = {}

## 防止空格按住时连续触发冲刺
var _dash_triggered: bool = false

## Sprite2D 节点的引用（用于独立旋转朝向）
@onready var _sprite: Sprite2D = $Sprite2D


# ============================================================
# 生命周期函数
# ============================================================

func _ready() -> void:
	# 确保出生位置在场景原点
	global_position = Vector2.ZERO
	# 将玩家加入 "player" 组，方便敌人查找
	add_to_group("player")
	print("[Player] 脚本已加载，等待输入... W/A/S/D=移动 空格=冲刺")


func _input(event: InputEvent) -> void:
	# 手动追踪按键状态 —— 最底层的输入检测方式
	if event is InputEventKey:
		_keys[event.keycode] = event.pressed


func _physics_process(delta: float) -> void:
	# 更新冲刺冷却计时
	if dash_cooldown_left > 0.0:
		dash_cooldown_left -= delta

	# 根据是否在冲刺中，调用不同的移动逻辑
	if is_dashing:
		_apply_dash_movement(delta)
	else:
		_apply_normal_movement(delta)

	# 每帧更新：角色朝向鼠标
	_face_mouse()


# ============================================================
# 常规移动（WASD）
# ============================================================

func _get_input_direction() -> Vector2:
	## 返回 WASD 输入方向（归一化向量）
	## 同时尝试 Input Map 动作和手动按键追踪
	var direction := Vector2.ZERO

	# 第一优先级：Input Map 动作检测
	if Input.is_action_pressed("move_right"):
		direction.x += 1.0
	if Input.is_action_pressed("move_left"):
		direction.x -= 1.0
	if Input.is_action_pressed("move_down"):
		direction.y += 1.0
	if Input.is_action_pressed("move_up"):
		direction.y -= 1.0

	# 第二优先级：手动追踪的按键状态
	if direction == Vector2.ZERO:
		if _keys.get(KEY_D, false):
			direction.x += 1.0
		if _keys.get(KEY_A, false):
			direction.x -= 1.0
		if _keys.get(KEY_S, false):
			direction.y += 1.0
		if _keys.get(KEY_W, false):
			direction.y -= 1.0

	return direction.normalized()


func _apply_normal_movement(delta: float) -> void:
	## 处理常规移动 + 检测冲刺输入
	var input_dir := _get_input_direction()

	if input_dir != Vector2.ZERO:
		velocity = input_dir * move_speed
	else:
		velocity = velocity.move_toward(Vector2.ZERO, move_speed * 10.0 * delta)

	move_and_slide()

	# 检测冲刺按键（空格）—— 边沿检测，按下瞬间触发一次
	var space_held: bool = _keys.get(KEY_SPACE, false) or Input.is_action_pressed("dash")
	if space_held and not _dash_triggered:
		_dash_triggered = true
		_start_dash()
	elif not space_held:
		_dash_triggered = false


# ============================================================
# 冲刺系统
# ============================================================

func _start_dash() -> void:
	## 尝试开始冲刺（检查冷却和状态后执行）
	if dash_cooldown_left > 0.0:
		return
	if is_dashing:
		return

	# 确定冲刺方向：优先移动输入方向，否则使用鼠标方向
	var dir := _get_input_direction()
	if dir == Vector2.ZERO:
		dir = (get_global_mouse_position() - global_position).normalized()

	if dir == Vector2.ZERO:
		return

	# 进入冲刺状态
	is_dashing = true
	dash_time_left = DASH_DURATION
	dash_direction = dir
	dash_cooldown_left = DASH_COOLDOWN


func _apply_dash_movement(delta: float) -> void:
	## 处理冲刺期间的移动
	dash_time_left -= delta

	if dash_time_left <= 0.0:
		is_dashing = false
		velocity = dash_direction * move_speed
	else:
		velocity = dash_direction * dash_speed

	move_and_slide()


# ============================================================
# 鼠标朝向 —— 仅旋转 Sprite2D
# ============================================================

func _face_mouse() -> void:
	## 让角色精灵始终面向鼠标光标位置
	if _sprite:
		var mouse_pos := get_global_mouse_position()
		_sprite.rotation = (mouse_pos - global_position).angle()


# ============================================================
# 公共接口
# ============================================================

func try_dash() -> bool:
	## 冲刺接口（外部调用），返回 true 表示成功触发
	if dash_cooldown_left > 0.0 or is_dashing:
		return false
	_start_dash()
	return true


func is_dash_ready() -> bool:
	## 查询冲刺是否可用
	return dash_cooldown_left <= 0.0 and not is_dashing


func get_current_speed() -> float:
	## 获取当前实际移动速度
	return dash_speed if is_dashing else move_speed


func get_dash_cooldown_ratio() -> float:
	## 获取冲刺冷却比例 [0.0, 1.0]，0 表示冷却完毕
	if DASH_COOLDOWN <= 0.0:
		return 0.0
	return clampf(dash_cooldown_left / DASH_COOLDOWN, 0.0, 1.0)
