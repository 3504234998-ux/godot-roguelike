extends CanvasLayer
## 调试信息覆盖层
## 负责：显示实时游戏数据 / 用于数值平衡调试 / 按 F1 切换显示


# ============================================================
# 节点引用（@onready）
# ============================================================

@onready var _fps_label: Label = $Panel/VBox/FPS
@onready var _wave_label: Label = $Panel/VBox/Wave
@onready var _enemy_label: Label = $Panel/VBox/EnemyCount
@onready var _level_label: Label = $Panel/VBox/Level
@onready var _stats_label: Label = $Panel/VBox/Stats
@onready var _pool_label: Label = $Panel/VBox/Pools


# ============================================================
# 生命周期函数
# ============================================================

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()


func _process(_delta: float) -> void:
	# F1 切换显示
	if Input.is_action_just_pressed("pause"):
		# pause 已用于 ESC，这里换用 F1 键盘检测
		pass
	if Input.is_key_pressed(KEY_F1):
		if visible:
			hide()
		else:
			show()
		# 简单防抖：等待下一帧
		await get_tree().process_frame

	if not visible:
		return

	# 更新 FPS
	_fps_label.text = "FPS: %d" % Engine.get_frames_per_second()

	# 更新波次
	var enemy_mgr: Node = _find_enemy_manager()
	if enemy_mgr:
		_wave_label.text = "波次: %d  时间: %.0fs" % [enemy_mgr.get_wave(), enemy_mgr.get_time_elapsed()]
		_enemy_label.text = "敌人数: %d" % enemy_mgr.get_enemy_count()

	# 更新玩家等级与属性
	var player: Node = _find_player()
	if player:
		var lv_ctrl: Node = player.get_node_or_null("LevelController")
		if lv_ctrl:
			_level_label.text = "等级: %d  经验: %d/%d" % [lv_ctrl.current_level, lv_ctrl.current_exp, lv_ctrl.get_exp_to_next()]

		var atk_ctrl: Node = player.get_node_or_null("AttackController")
		if atk_ctrl:
			_stats_label.text = "伤害: %d  间隔: %.2fs  子弹: %d  穿透: %d  弹速: %.0f" % [
				atk_ctrl.current_damage, atk_ctrl.attack_interval, atk_ctrl.bullet_count, atk_ctrl.pierce_count, atk_ctrl.current_bullet_speed
			]

	# 更新对象池统计
	if is_instance_valid(ObjectPoolManager):
		var bs: Dictionary = ObjectPoolManager.get_bullet_stats()
		var es: Dictionary = ObjectPoolManager.get_enemy_stats()
		var os: Dictionary = ObjectPoolManager.get_exp_orb_stats()
		_pool_label.text = "池 — 子弹:%d/%d  敌人:%d/%d  经验球:%d/%d" % [
			bs.get("active", 0), bs.get("total", 0),
			es.get("active", 0), es.get("total", 0),
			os.get("active", 0), os.get("total", 0),
		]


func _find_enemy_manager() -> Node:
	var nodes := get_tree().get_nodes_in_group("enemy_manager")
	if nodes.is_empty():
		return null
	return nodes[0]


func _find_player() -> Node:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return null
	return players[0]
