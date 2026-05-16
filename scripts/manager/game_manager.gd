extends Node
## GameManager — 游戏管理器（Autoload 单例）
## 负责：游戏状态 / 时间管理 / 暂停 / 游戏结束 / 存档数据收集与恢复
## 通过 project.godot 的 [autoload] 注册为全局节点


# ============================================================
# 枚举
# ============================================================

## 游戏状态
enum GameState {
	PLAYING,     # 游戏中
	PAUSED,      # 已暂停
	GAME_OVER,   # 游戏结束
}


# ============================================================
# 信号
# ============================================================

## 游戏开始 / 重新开始
signal game_started

## 游戏暂停
signal game_paused

## 游戏从暂停恢复
signal game_resumed

## 游戏结束（携带最终存活时间）
signal game_over(total_time: float)

## 时间每秒更新（供 UI 显示）
signal time_changed(seconds: float)


# ============================================================
# 内部状态变量
# ============================================================

## 当前游戏状态
var current_state: GameState = GameState.PLAYING

## 游戏已运行时间（秒）
var elapsed_time: float = 0.0

## 距上次 time_changed 信号发射的时间累积
var _time_signal_accum: float = 0.0

## 玩家是否已连接（防止重复连接信号）
var _player_connected: bool = false

## 是否正在升级选择中（阻止 ESC 恢复游戏）
var is_upgrading: bool = false

## 全局击杀计数（供 GameOverUI 显示）
var total_kills: int = 0

## 待恢复的存档数据（非空时表示需要在新场景加载后恢复状态）
var _restore_data: Dictionary = {}

## 是否正在执行存档恢复（阻止恢复过程中的自动存档触发）
var _is_restoring: bool = false


# ============================================================
# 生命周期函数
# ============================================================

func _ready() -> void:
	# 确保 GameManager 在暂停状态下也能运行（接收 ESC 按键）
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("[GameManager] Autoload 就绪 — 状态: PLAYING")


func _process(delta: float) -> void:
	# 仅在游戏进行中更新时间
	if current_state == GameState.PLAYING:
		elapsed_time += delta
		# 每秒发射一次 time_changed 信号（避免每帧发射）
		_time_signal_accum += delta
		if _time_signal_accum >= 1.0:
			_time_signal_accum -= 1.0
			time_changed.emit(elapsed_time)

	# 检测暂停按键（任何状态下均可响应）
	if Input.is_action_just_pressed("pause"):
		_toggle_pause()

	# 首次查找玩家并连接死亡信号
	if not _player_connected and current_state != GameState.GAME_OVER:
		_try_connect_player()


# ============================================================
# 暂停系统
# ============================================================

func _toggle_pause() -> void:
	## 切换暂停/恢复状态
	if current_state == GameState.GAME_OVER:
		return
	# 升级选择中不允许 ESC 切换暂停
	if is_upgrading:
		return

	if current_state == GameState.PLAYING:
		pause_game()
	elif current_state == GameState.PAUSED:
		resume_game()


func pause_game() -> void:
	## 暂停游戏
	current_state = GameState.PAUSED
	get_tree().paused = true
	game_paused.emit()
	print("[GameManager] 游戏已暂停")


func resume_game() -> void:
	## 恢复游戏
	current_state = GameState.PLAYING
	get_tree().paused = false
	game_resumed.emit()
	print("[GameManager] 游戏已恢复")


# ============================================================
# 游戏结束
# ============================================================

func end_game() -> void:
	## 游戏结束（玩家死亡时调用）
	if current_state == GameState.GAME_OVER:
		return

	current_state = GameState.GAME_OVER
	get_tree().paused = true
	game_over.emit(elapsed_time)
	print("[GameManager] 游戏结束！存活时间: %.1f 秒" % elapsed_time)


# ============================================================
# 玩家信号连接
# ============================================================

func _try_connect_player() -> void:
	## 尝试查找玩家并连接死亡信号（每帧重试直到成功）
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return

	var player: Node = players[0]
	var health: Node = player.get_node_or_null("HealthController")
	if health and health.has_signal("player_died"):
		health.player_died.connect(_on_player_died)
		_player_connected = true
		print("[GameManager] 已连接玩家死亡信号")

	# 如果有待恢复的存档数据，在此应用（此时场景已完全就绪）
	if not _restore_data.is_empty():
		_apply_restore_data(player)
		_restore_data.clear()

	# 连接波次变化信号（用于自动存档）
	_connect_wave_signal()


func _connect_wave_signal() -> void:
	## 连接 EnemyManager 的 wave_changed 信号（自动存档触发点）
	var mgrs := get_tree().get_nodes_in_group("enemy_manager")
	if mgrs.is_empty():
		return
	var enemy_mgr: Node = mgrs[0]
	if enemy_mgr.has_signal("wave_changed") and not enemy_mgr.wave_changed.is_connected(_on_wave_changed):
		enemy_mgr.wave_changed.connect(_on_wave_changed)


func _on_player_died() -> void:
	## 玩家死亡回调 → 触发游戏结束
	end_game()


func _on_wave_changed(_wave: int) -> void:
	## 波次变化时自动存档（恢复过程中跳过，避免覆盖正在恢复的存档）
	if _is_restoring:
		return
	if current_state == GameState.PLAYING:
		_save_game_data(0)
		print("[GameManager] 自动存档 — 波次 %d" % _wave)


# ============================================================
# 存档数据收集
# ============================================================

func _save_game_data(slot: int) -> void:
	## 收集当前游戏状态并保存到指定槽位
	var save_data: Dictionary = get_save_data()
	SaveManager.save_game(slot, save_data)


func get_save_data() -> Dictionary:
	## 收集完整的游戏状态数据（供 SaveManager 和外部调用）
	var data: Dictionary = {
		"play_time": elapsed_time,
		"player": _get_player_save_data(),
		"weapons": _get_weapon_save_data(),
		"upgrades_applied": _get_upgrades_save_data(),
		"game": {
			"wave": _get_current_wave(),
			"total_kills": total_kills,
		},
	}
	return data


func _get_player_save_data() -> Dictionary:
	## 收集玩家状态数据
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return {}

	var player: Node2D = players[0]

	var data: Dictionary = {
		"position_x": player.global_position.x,
		"position_y": player.global_position.y,
	}

	# 生命值
	var health: Node = player.get_node_or_null("HealthController")
	if health:
		data["hp"] = health.get("current_hp")
		data["max_hp"] = health.get("max_hp")

	# 等级 + 经验
	var level_ctrl: Node = player.get_node_or_null("LevelController")
	if level_ctrl:
		data["level"] = level_ctrl.get("current_level")
		data["exp"] = level_ctrl.get("current_exp")

	# 移动速度（player_controller.gd 直接挂载在 Player 节点上）
	if player is CharacterBody2D:
		data["move_speed_base"] = (player as CharacterBody2D).get("move_speed")

	return data


func _get_weapon_save_data() -> Array:
	## 收集所有武器槽位数据
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return []

	var player: Node = players[0]
	var attack_ctrl: Node = player.get_node_or_null("AttackController")
	if not attack_ctrl or not attack_ctrl.has_method("get_weapon_save_data"):
		return []

	return attack_ctrl.get_weapon_save_data()


func _get_upgrades_save_data() -> Array:
	## 收集已应用升级列表
	var mgrs := get_tree().get_nodes_in_group("upgrade_manager")
	if mgrs.is_empty():
		return []

	var upgrade_mgr: Node = mgrs[0]
	if upgrade_mgr.has_method("get_applied_upgrades"):
		return upgrade_mgr.get_applied_upgrades()

	return []


func _get_current_wave() -> int:
	## 获取当前波次
	var mgrs := get_tree().get_nodes_in_group("enemy_manager")
	if mgrs.is_empty():
		return 1

	var enemy_mgr: Node = mgrs[0]
	if enemy_mgr.has_method("get_wave"):
		return enemy_mgr.get_wave()

	return 1


# ============================================================
# 存档恢复
# ============================================================

func _apply_restore_data(player: Node) -> void:
	## 将存档数据应用到当前场景
	_is_restoring = true
	print("[GameManager] 正在恢复存档数据...")

	# 1. 恢复玩家属性
	_restore_player(player)

	# 2. 恢复游戏状态
	_restore_game_state()

	# 3. 恢复武器（需要等玩家和 WeaponManager 就绪）
	_restore_weapons(player)

	# 4. 恢复升级（需要等 UpgradeManager 就绪）
	_restore_upgrades()

	_is_restoring = false
	print("[GameManager] 存档恢复完成")


func _restore_player(player: Node) -> void:
	## 恢复玩家位置、生命、等级、移速
	var pdata: Dictionary = _restore_data.get("player", {})
	if pdata.is_empty():
		return

	# 位置
	if pdata.has("position_x") and player is Node2D:
		(player as Node2D).global_position = Vector2(
			pdata.get("position_x", 0.0),
			pdata.get("position_y", 0.0)
		)

	# 生命值
	var health: Node = player.get_node_or_null("HealthController")
	if health:
		if pdata.has("max_hp"):
			health.set("max_hp", pdata["max_hp"])
		if pdata.has("hp"):
			health.set("current_hp", pdata["hp"])
		# 通知 UI 更新
		if health.has_signal("health_changed"):
			health.health_changed.emit(health.get("current_hp"), health.get("max_hp"))

	# 等级 + 经验
	var level_ctrl: Node = player.get_node_or_null("LevelController")
	if level_ctrl:
		if pdata.has("level"):
			level_ctrl.set("current_level", pdata["level"])
			# 发射信号让 HUD 更新等级显示
			if level_ctrl.has_signal("leveled_up"):
				level_ctrl.leveled_up.emit(pdata["level"])
		if pdata.has("exp"):
			level_ctrl.set("current_exp", pdata["exp"])
			# 发射经验变化信号让 HUD 更新经验条
			if level_ctrl.has_signal("exp_changed") and level_ctrl.has_method("get_exp_to_next"):
				level_ctrl.exp_changed.emit(pdata["exp"], level_ctrl.get_exp_to_next())

	# 移动速度（player_controller.gd 直接挂载在 Player 节点上）
	if pdata.has("move_speed_base") and player is CharacterBody2D:
		(player as CharacterBody2D).set("move_speed", pdata["move_speed_base"])


func _restore_game_state() -> void:
	## 恢复游戏全局状态
	var gdata: Dictionary = _restore_data.get("game", {})
	if gdata.is_empty():
		return

	elapsed_time = _restore_data.get("play_time", 0.0)
	total_kills = gdata.get("total_kills", 0)

	# 通知 UI 当前时间
	time_changed.emit(elapsed_time)

	# 波次恢复
	if gdata.has("wave"):
		var target_wave: int = gdata["wave"]
		var mgrs := get_tree().get_nodes_in_group("enemy_manager")
		if not mgrs.is_empty():
			var enemy_mgr: Node = mgrs[0]
			if enemy_mgr.has_method("set_wave_for_restore"):
				enemy_mgr.set_wave_for_restore(target_wave)


func _restore_weapons(player: Node) -> void:
	## 恢复武器槽位
	var weapons_data: Array = _restore_data.get("weapons", [])
	if weapons_data.is_empty():
		return

	var attack_ctrl: Node = player.get_node_or_null("AttackController")
	if not attack_ctrl or not attack_ctrl.has_method("restore_weapons"):
		return

	attack_ctrl.restore_weapons(weapons_data)


func _restore_upgrades() -> void:
	## 恢复已应用的升级
	var upgrades: Array = _restore_data.get("upgrades_applied", [])
	if upgrades.is_empty():
		return

	var mgrs := get_tree().get_nodes_in_group("upgrade_manager")
	if mgrs.is_empty():
		return

	var upgrade_mgr: Node = mgrs[0]
	if upgrade_mgr.has_method("restore_upgrades"):
		upgrade_mgr.restore_upgrades(upgrades)


# ============================================================
# 公共接口
# ============================================================

func get_elapsed_time() -> float:
	## 获取当前游戏运行时间（秒）
	return elapsed_time


func get_state() -> GameState:
	## 获取当前游戏状态
	return current_state


func is_playing() -> bool:
	## 是否正在游戏中
	return current_state == GameState.PLAYING


func is_paused() -> bool:
	## 是否已暂停
	return current_state == GameState.PAUSED


func is_game_over() -> bool:
	## 是否游戏结束
	return current_state == GameState.GAME_OVER


func get_kill_count() -> int:
	## 获取全局击杀计数
	return total_kills


func add_kill(count: int = 1) -> void:
	## 增加击杀计数
	total_kills += count


func return_to_menu() -> void:
	## 返回主菜单（重置状态 + 切换场景）
	_reset_state()
	get_tree().change_scene_to_file("res://scenes/main/MainMenu.tscn")


func restart_game() -> void:
	## 重新开始游戏（重置状态 + 重新加载游戏场景）
	_reset_state()
	get_tree().change_scene_to_file("res://scenes/main/MainScene.tscn")


func continue_game(slot: int = 0) -> void:
	## 继续游戏：读取存档 → 切场景 → 恢复状态
	if not SaveManager.has_save(slot):
		push_warning("[GameManager] 槽位 %d 没有存档，无法继续" % slot)
		return

	var data: Dictionary = SaveManager.load_game(slot)
	if data.is_empty():
		push_warning("[GameManager] 槽位 %d 存档读取失败" % slot)
		return

	# 使用 SaveManager 跨场景传递数据（Autoload 在场景切换时保持）
	SaveManager.set_pending_load(data)

	# 存储一份在 GameManager 自身（也是在 Autoload 中，场景切换不丢失）
	_restore_data = data

	# 重置状态变量（这些会被 _apply_restore_data 覆盖）
	elapsed_time = 0.0
	_time_signal_accum = 0.0
	total_kills = 0
	is_upgrading = false
	_player_connected = false
	current_state = GameState.PLAYING
	get_tree().paused = false

	# 切换到游戏场景（_try_connect_player 会在玩家就绪后自动恢复）
	get_tree().change_scene_to_file("res://scenes/main/MainScene.tscn")
	print("[GameManager] 继续游戏 — 从槽位 %d 恢复" % slot)


func save_and_quit() -> void:
	## 保存游戏并返回主菜单
	_save_game_data(0)
	return_to_menu()


func _reset_state() -> void:
	## 重置所有游戏状态变量
	elapsed_time = 0.0
	_time_signal_accum = 0.0
	total_kills = 0
	is_upgrading = false
	_player_connected = false
	_restore_data.clear()
	current_state = GameState.PLAYING
	get_tree().paused = false
