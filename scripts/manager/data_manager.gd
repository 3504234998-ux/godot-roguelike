extends Node
## 数据管理器（Autoload 单例）
## 负责：统一加载所有 JSON 配置 / 提供数据查询接口
## 所有游戏数据通过此类获取，禁止在各系统中硬编码数值


# ============================================================
# 信号
# ============================================================

## 所有数据加载完成
signal data_loaded


# ============================================================
# 导出变量
# ============================================================

## 敌人数据 JSON 文件路径
@export var enemy_data_path: String = "res://data/enemy_data.json"

## 升级数据 JSON 文件路径
@export var upgrade_data_path: String = "res://data/upgrade_data.json"

## 波次刷怪权重 JSON 文件路径
@export var wave_data_path: String = "res://data/wave_data.json"

## 游戏平衡参数 JSON 文件路径
@export var balance_data_path: String = "res://data/game_balance.json"

## 武器数据 JSON 文件路径
@export var weapon_data_path: String = "res://data/weapon_data.json"


# ============================================================
# 内部状态变量
# ============================================================

## 敌人数据缓存（key=敌人类型ID, value=属性字典）
var _enemy_data: Dictionary = {}

## 升级数据缓存（数组，元素为升级配置字典）
var _upgrade_data: Array = []

## 波次刷怪权重缓存（数组，元素为波次配置字典）
var _wave_data: Array = []

## 游戏平衡参数缓存
var _balance_data: Dictionary = {}

## 武器数据缓存
var _weapon_data: Dictionary = {}

## 是否已完成加载
var _is_loaded: bool = false


# ============================================================
# 生命周期函数
# ============================================================

func _ready() -> void:
	# DataManager 必须在暂停时也能被访问（用于读取配置）
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_all()
	print("[DataManager] 数据管理器就绪 — 敌人类型: %d  升级模板: %d  武器: %d" % [_enemy_data.size(), _upgrade_data.size(), _weapon_data.size()])


# ============================================================
# 数据加载
# ============================================================

func _load_all() -> void:
	## 加载所有 JSON 配置文件
	_enemy_data = _load_json(enemy_data_path, {})
	_upgrade_data = _load_json(upgrade_data_path, [])
	_wave_data = _load_json(wave_data_path, [])
	_balance_data = _load_json(balance_data_path, {})
	_weapon_data = _load_json(weapon_data_path, {})
	_is_loaded = true
	data_loaded.emit()


func _load_json(path: String, default):
	## 通用 JSON 文件加载函数
	## path: 文件路径  default: 解析失败时的默认返回值
	if not FileAccess.file_exists(path):
		push_error("[DataManager] 找不到数据文件: %s" % path)
		return default

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("[DataManager] 无法打开文件: %s" % path)
		return default

	var json: JSON = JSON.new()
	var error: Error = json.parse(file.get_as_text())
	file.close()

	if error != OK:
		push_error("[DataManager] JSON 解析失败 (%s): 行%d — %s" % [path, json.get_error_line(), json.get_error_message()])
		return default

	var result = json.get_data()
	print("[DataManager] 已加载: %s (%d 条记录)" % [path, result.size() if result is Array else result.size() if result is Dictionary else 0])
	return result


# ============================================================
# 敌人数据查询
# ============================================================

func get_enemy_data(enemy_type: String) -> Dictionary:
	## 根据敌人类型ID获取属性配置
	## 返回副本以避免外部意外修改缓存
	if not _enemy_data.has(enemy_type):
		push_warning("[DataManager] 未找到敌人类型: %s，返回空字典" % enemy_type)
		return {}
	return _enemy_data[enemy_type].duplicate(true)


func get_all_enemy_types() -> Array:
	## 获取所有敌人类型ID列表
	return _enemy_data.keys()


func has_enemy_type(enemy_type: String) -> bool:
	## 检查指定敌人类型是否存在
	return _enemy_data.has(enemy_type)


func get_random_enemy_type() -> String:
	## 随机获取一个敌人类型ID（供刷怪系统使用）
	var keys: Array = _enemy_data.keys()
	if keys.is_empty():
		return ""
	return keys[randi() % keys.size()]


# ============================================================
# 波次刷怪权重查询
# ============================================================

func get_weapon_data(weapon_id: String) -> Dictionary:
	## 获取指定武器的配置数据
	if not _weapon_data.has(weapon_id):
		push_warning("[DataManager] 未找到武器数据: %s" % weapon_id)
		return {}
	return _weapon_data[weapon_id].duplicate(true)


func get_wave_spawn_weights(wave: int) -> Dictionary:
	## 根据当前波次获取刷怪权重表
	## 返回 {"enemy_type": weight, ...}，未匹配时返回全部敌人等权重
	for entry: Dictionary in _wave_data:
		var start: int = entry.get("wave_start", 1)
		var end: int = entry.get("wave_end", 999)
		if wave >= start and wave <= end:
			return entry.get("spawn_weights", {}).duplicate(true)

	# 回退：所有敌人类型等权重
	var fallback: Dictionary = {}
	for key: String in _enemy_data.keys():
		fallback[key] = 1
	return fallback


func get_wave_config(wave: int) -> Dictionary:
	## 根据当前波次获取完整波次配置
	for entry: Dictionary in _wave_data:
		var start: int = entry.get("wave_start", 1)
		var end: int = entry.get("wave_end", 999)
		if wave >= start and wave <= end:
			return entry.duplicate(true)
	return {}


# ============================================================
# 升级数据查询
# ============================================================

func get_upgrade_pool() -> Array:
	## 获取全部升级配置（返回副本）
	return _upgrade_data.duplicate(true)


func get_upgrade_by_id(upgrade_id: String) -> Dictionary:
	## 根据升级ID获取单个升级配置
	for upgrade: Dictionary in _upgrade_data:
		if upgrade.get("id", "") == upgrade_id:
			return upgrade.duplicate(true)
	push_warning("[DataManager] 未找到升级ID: %s" % upgrade_id)
	return {}


func get_upgrade_count() -> int:
	## 获取升级模板总数
	return _upgrade_data.size()


# ============================================================
# 游戏平衡查询
# ============================================================

func get_balance() -> Dictionary:
	## 获取全部平衡配置（返回副本）
	return _balance_data.duplicate(true)


func get_balance_value(path: String, default = null):
	## 通过路径字符串获取平衡参数值
	## 例如: "enemy_wave_scaling.hp_multiplier" → 0.06
	var keys: PackedStringArray = path.split(".")
	var current = _balance_data
	for key: String in keys:
		if current is Dictionary and current.has(key):
			current = current[key]
		else:
			return default
	return current


func get_enemy_wave_scaling(wave: int, stat: String) -> float:
	## 计算波次属性倍率。公式: 1 + multiplier * (wave - 1)
	var multiplier: float = _balance_data.get("enemy_wave_scaling", {}).get(stat + "_multiplier", 0.0)
	return 1.0 + multiplier * float(wave - 1)


# ============================================================
# 通用查询
# ============================================================

func is_loaded() -> bool:
	## 数据是否已完成加载
	return _is_loaded


func reload_all() -> void:
	## 重新加载所有数据（用于热更新或调试）
	_enemy_data.clear()
	_upgrade_data.clear()
	_wave_data.clear()
	_balance_data.clear()
	_is_loaded = false
	_load_all()
	print("[DataManager] 数据已重新加载")
