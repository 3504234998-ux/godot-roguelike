extends CharacterBody2D
## 敌人控制器
## 负责：自动寻找玩家 / 追踪移动 / 碰撞检测


# ============================================================
# 导出变量（可在编辑器中调整）
# ============================================================

## 追踪移动速度（像素/秒）
@export var move_speed: float = 120.0

## 停止追踪的距离（像素），小于此距离不再靠近玩家
@export var stop_distance: float = 8.0


# ============================================================
# 内部状态变量
# ============================================================

## 缓存玩家引用（首次找到后缓存，避免每帧查找）
var _player: CharacterBody2D = null


# ============================================================
# 生命周期函数
# ============================================================

func _ready() -> void:
	# 不在 _ready 中 add_to_group("enemy")，否则对象池中的敌人也会被计入
	# 改为在 reset_state() 中添加（仅当敌人被实际使用时）
	call_deferred("_find_player")


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(_player):
		_find_player()
		return

	var to_player: Vector2 = _player.global_position - global_position
	var distance: float = to_player.length()

	if distance < stop_distance:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var direction: Vector2 = to_player.normalized()
	velocity = direction * move_speed
	move_and_slide()

	_face_player(direction)


# ============================================================
# 玩家查找
# ============================================================

func _find_player() -> void:
	## 在场景树中查找玩家节点（通过 "player" 组）
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0] as CharacterBody2D


# ============================================================
# 视觉朝向
# ============================================================

func _face_player(direction: Vector2) -> void:
	## 让敌人精灵朝向追踪方向
	var sprite: Sprite2D = $Sprite2D as Sprite2D
	if sprite:
		sprite.rotation = direction.angle()


# ============================================================
# 公共接口
# ============================================================

func set_player(target: CharacterBody2D) -> void:
	_player = target


func get_move_speed() -> float:
	return move_speed


func hit_flash() -> void:
	## 受击闪白效果
	var sprite: Sprite2D = get_node_or_null("Sprite2D")
	if not sprite:
		return
	var original: Color = sprite.modulate
	sprite.modulate = Color.WHITE
	var tween: Tween = create_tween()
	tween.tween_property(sprite, "modulate", original, 0.12)


func reset_state() -> void:
	## 重置敌人状态（由对象池 acquire 时调用）
	if not is_in_group("enemy"):
		add_to_group("enemy")
	_player = null
	visible = true
	collision_layer = 2
	collision_mask = 1

	var sprite: Sprite2D = get_node_or_null("Sprite2D")
	if sprite:
		sprite.rotation = 0.0
		sprite.visible = true

	# 移除动态创建的精英血条之前，先断开血量信号旧连接
	var bar: Node = get_node_or_null("EnemyHealthBar")
	if bar:
		var health_node: Node = get_node_or_null("Health")
		if health_node and health_node.has_signal("health_changed"):
			for conn in health_node.health_changed.get_connections():
				health_node.health_changed.disconnect(conn["callable"])
		bar.queue_free()

	scale = Vector2.ONE

	var health: Node = get_node_or_null("Health")
	if health and health.has_method("reset_state"):
		health.reset_state()


func configure(data: Dictionary) -> void:
	## 根据数据字典配置敌人属性
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
		var sprite: Sprite2D = get_node_or_null("Sprite2D")
		if sprite and ResourceLoader.exists(data["sprite_path"]):
			sprite.texture = load(data["sprite_path"])
		elif sprite and data.has("color"):
			sprite.modulate = Color(data["color"]["r"], data["color"]["g"], data["color"]["b"], data["color"].get("a", 1.0))
	elif data.has("color"):
		var sprite: Sprite2D = get_node_or_null("Sprite2D")
		if sprite:
			sprite.modulate = Color(data["color"]["r"], data["color"]["g"], data["color"]["b"], data["color"].get("a", 1.0))

	if data.has("scale"):
		scale = Vector2(data["scale"], data["scale"])

	if data.get("is_elite", false):
		_setup_elite()


func _on_pool_release() -> void:
	## 回池前清理：移除 enemy 组 + 清零碰撞层
	if is_in_group("enemy"):
		remove_from_group("enemy")
	_player = null
	collision_layer = 0
	collision_mask = 0


func _setup_elite() -> void:
	## 精英怪初始化：创建头顶血条（首次或重新配置时均先清理旧血条）
	# 先清理可能已存在的旧血条和信号连接
	var old_bar: Node = get_node_or_null("EnemyHealthBar")
	var health: Node = get_node_or_null("Health")
	if old_bar and health and health.has_signal("health_changed"):
		for conn in health.health_changed.get_connections():
			health.health_changed.disconnect(conn["callable"])
		old_bar.queue_free()

	if not health:
		return

	var bar: Node2D = Node2D.new()
	bar.name = "EnemyHealthBar"
	bar.position.y = -30.0

	var bg: ColorRect = ColorRect.new()
	bg.name = "BarBG"
	bg.size = Vector2(40, 5)
	bg.position = Vector2(-20, -2.5)
	bg.color = Color(0, 0, 0, 0.6)
	bar.add_child(bg)

	var fill: ColorRect = ColorRect.new()
	fill.name = "BarFill"
	fill.size = Vector2(40, 5)
	fill.position = Vector2(-20, -2.5)
	fill.color = Color(1.0, 0.3, 0.3, 1.0)
	bar.add_child(fill)

	add_child(bar)

	# 连接血量变化信号（is_instance_valid 防止 fill 被释放后崩溃）
	var _max_w: float = 40.0
	health.health_changed.connect(func(cur: int, mx: int):
		if not is_instance_valid(fill):
			return
		var ratio: float = clampf(float(cur) / float(mx), 0.0, 1.0)
		fill.size.x = _max_w * ratio
		if ratio < 0.3:
			fill.color = Color(1.0, 0.2, 0.2, 1.0)
	)
