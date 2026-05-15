extends Node
## GameManager — 游戏管理器（Autoload 单例）
## 负责：游戏状态 / 时间管理 / 暂停 / 游戏结束
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
	print("[GameManager] 💀 游戏结束！存活时间: %.1f 秒" % elapsed_time)


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


func _on_player_died() -> void:
	## 玩家死亡回调 → 触发游戏结束
	end_game()


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
	elapsed_time = 0.0
	_time_signal_accum = 0.0
	total_kills = 0
	is_upgrading = false
	_player_connected = false
	current_state = GameState.PLAYING
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main/MainMenu.tscn")


func restart_game() -> void:
	## 重新开始游戏（重置状态 + 重新加载游戏场景）
	elapsed_time = 0.0
	_time_signal_accum = 0.0
	total_kills = 0
	is_upgrading = false
	_player_connected = false
	current_state = GameState.PLAYING
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main/MainScene.tscn")
