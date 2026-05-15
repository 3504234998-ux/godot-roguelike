extends Node
## 升级管理器
## 负责：加载升级数据 / 随机三选一 / 应用强化效果 / 管理升级队列
## 通过 Signal 与 LevelController 和 UpgradeUI 通信


# ============================================================
# 信号
# ============================================================

## 升级选项已生成，通知 UI 显示
signal options_ready(options: Array)

## 升级已应用
signal upgrade_applied(upgrade_id: String, upgrade_name: String)


# ============================================================
# 导出变量（可在编辑器中调整）
# ============================================================

## 每次显示的升级选项数量
@export var option_count: int = 3


# ============================================================
# 内部状态变量
# ============================================================

## 待处理的升级次数（支持连续多次升级排队）
var _pending_count: int = 0

## 玩家引用（缓存）
var _player: Node = null

## UpgradeUI 引用
var _upgrade_ui: CanvasLayer = null


# ============================================================
# 生命周期函数
# ============================================================

func _ready() -> void:
	add_to_group("upgrade_manager")
	call_deferred("_connect_signals")
	print("[UpgradeManager] 升级管理器就绪")


# ============================================================
# 信号连接
# ============================================================

func _connect_signals() -> void:
	## 查找玩家并连接升级信号
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		push_warning("[UpgradeManager] 未找到玩家，无法连接升级信号")
		return

	_player = players[0]
	var level_ctrl: Node = _player.get_node_or_null("LevelController")
	if level_ctrl and level_ctrl.has_signal("upgrade_available"):
		level_ctrl.upgrade_available.connect(_on_upgrade_available)

	# 查找 UpgradeUI
	var ui_nodes := get_tree().get_nodes_in_group("upgrade_ui")
	if not ui_nodes.is_empty():
		_upgrade_ui = ui_nodes[0] as CanvasLayer


# ============================================================
# 升级触发
# ============================================================

func _on_upgrade_available(_level: int) -> void:
	## 玩家升级时触发：累加待处理数 → 暂停游戏 → 展示选项
	_pending_count += 1

	if _pending_count == 1:
		# 第一次升级：暂停游戏并展示 UI
		_show_options()


func _show_options() -> void:
	## 随机选取升级选项并通知 UI
	var options: Array = _pick_random(option_count)
	if options.is_empty():
		push_error("[UpgradeManager] 无法选取升级选项，升级池为空")
		_pending_count -= 1
		return

	# 暂停游戏并阻止 ESC 恢复
	GameManager.is_upgrading = true
	GameManager.pause_game()

	# 显示 UI
	if _upgrade_ui and _upgrade_ui.has_method("show_options"):
		_upgrade_ui.show_options(options)

	options_ready.emit(options)
	print("[UpgradeManager] 已生成 %d 个升级选项（剩余待处理: %d）" % [options.size(), _pending_count - 1])


# ============================================================
# 随机三选一
# ============================================================

func _pick_random(count: int) -> Array:
	## 从升级池中随机选取不重复的升级选项
	var pool: Array = DataManager.get_upgrade_pool()
	if pool.is_empty():
		return []

	var available: Array = pool.duplicate()
	var picked: Array = []

	for i in range(mini(count, available.size())):
		var idx: int = randi() % available.size()
		picked.append(available[idx])
		available.remove_at(idx)

	return picked


# ============================================================
# 应用升级（供 UpgradeUI 调用）
# ============================================================

func apply_upgrade(upgrade_data: Dictionary) -> void:
	## 应用一个升级效果
	if _player == null:
		# 重新尝试查找玩家
		var players := get_tree().get_nodes_in_group("player")
		if players.is_empty():
			push_error("[UpgradeManager] 无法应用升级：未找到玩家")
			return
		_player = players[0]

	var target: String = upgrade_data.get("target", "")
	var value = upgrade_data.get("value", 0)
	var operation: String = upgrade_data.get("operation", "")
	var upgrade_id: String = upgrade_data.get("id", "")
	var upgrade_name: String = upgrade_data.get("name", "")

	match target:
		"attack_damage":
			_apply_attack_damage(value, operation)
		"attack_speed":
			_apply_attack_speed(value, operation)
		"bullet_count":
			_apply_bullet_count(value)
		"move_speed":
			_apply_move_speed(value, operation)
		"max_hp":
			_apply_max_hp(value, operation)
		"bullet_pierce":
			_apply_bullet_pierce(value)
		"bullet_speed":
			_apply_bullet_speed(value, operation)
		"heal":
			_apply_heal(value, operation)
		_:
			push_warning("[UpgradeManager] 未知的升级目标: %s" % target)

	upgrade_applied.emit(upgrade_id, upgrade_name)
	print("[UpgradeManager] 已应用升级: %s (target=%s, value=%s, op=%s)" % [upgrade_name, target, value, operation])

	# 处理升级队列
	_pending_count -= 1
	if _pending_count > 0:
		_show_options()
	else:
		# 无待处理升级：关闭 UI → 恢复游戏
		if _upgrade_ui and _upgrade_ui.has_method("hide_options"):
			_upgrade_ui.hide_options()
		GameManager.is_upgrading = false
		GameManager.resume_game()


# ============================================================
# 升级效果实现
# ============================================================

func _get_attack_ctrl() -> Node:
	## 获取玩家的攻击控制器
	return _player.get_node_or_null("AttackController")


func _get_player_ctrl() -> CharacterBody2D:
	## 获取玩家移动控制器
	return _player as CharacterBody2D


func _get_health_ctrl() -> Node:
	## 获取玩家生命值控制器
	return _player.get_node_or_null("HealthController")


# --- 攻击力 ---

func _apply_attack_damage(value, operation: String) -> void:
	var ctrl: Node = _get_attack_ctrl()
	if not ctrl:
		return
	match operation:
		"percent_increase":
			var bonus: int = maxi(int(ctrl.current_damage * value / 100.0), 1)
			ctrl.current_damage += bonus
		"add":
			ctrl.current_damage += int(value)


# --- 攻速 ---

func _apply_attack_speed(value, operation: String) -> void:
	var ctrl: Node = _get_attack_ctrl()
	if not ctrl:
		return
	match operation:
		"percent_increase":
			# 攻速提升 = 攻击间隔缩短
			ctrl.attack_interval *= (1.0 - value / 100.0)
			ctrl.attack_interval = maxf(ctrl.attack_interval, 0.1)


# --- 弹幕数量 ---

func _apply_bullet_count(value) -> void:
	var ctrl: Node = _get_attack_ctrl()
	if not ctrl:
		return
	ctrl.bullet_count += int(value)


# --- 移速 ---

func _apply_move_speed(value, operation: String) -> void:
	var ctrl: CharacterBody2D = _get_player_ctrl()
	if not ctrl:
		return
	match operation:
		"percent_increase":
			ctrl.move_speed *= (1.0 + value / 100.0)


# --- 最大生命 ---

func _apply_max_hp(value, operation: String) -> void:
	var ctrl: Node = _get_health_ctrl()
	if not ctrl:
		return
	match operation:
		"add":
			var amount: int = int(value)
			ctrl.max_hp += amount
			# 同时治疗等量生命值
			if ctrl.has_method("heal"):
				ctrl.heal(amount)


# --- 子弹穿透 ---

func _apply_bullet_pierce(value) -> void:
	var ctrl: Node = _get_attack_ctrl()
	if not ctrl:
		return
	ctrl.pierce_count += int(value)


# --- 子弹速度 ---

func _apply_bullet_speed(value, operation: String) -> void:
	var ctrl: Node = _get_attack_ctrl()
	if not ctrl:
		return
	match operation:
		"percent_increase":
			ctrl.current_bullet_speed *= (1.0 + value / 100.0)


# --- 治疗 ---

func _apply_heal(value, operation: String) -> void:
	var ctrl: Node = _get_health_ctrl()
	if not ctrl:
		return
	match operation:
		"percent_heal":
			var heal_amount: int = int(ctrl.max_hp * value / 100.0)
			if ctrl.has_method("heal"):
				ctrl.heal(heal_amount)


# ============================================================
# 公共接口
# ============================================================

func get_pending_count() -> int:
	## 获取待处理的升级次数
	return _pending_count


func get_upgrade_pool_size() -> int:
	## 获取升级池大小
	return DataManager.get_upgrade_count()
