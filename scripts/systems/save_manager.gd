extends Node
## SaveManager — 存档管理器（Autoload 单例）
## 负责：存档 / 读档 / 删除 的 JSON 文件 I/O
## 通过 project.godot 的 [autoload] 注册为全局节点


# ============================================================
# 常量
# ============================================================

const SAVE_DIR: String = "user://saves/"
const SAVE_FILE_TEMPLATE: String = "save_%03d.json"
const SAVE_CONFIG_PATH: String = "res://data/save_config.json"


# ============================================================
# 内部状态变量
# ============================================================

## 当前存档版本号（从 save_config.json 读取）
var _save_version: String = "0.2.0"

## 最大存档槽位数
var _max_slots: int = 3

## 待恢复的存档数据（读档后暂存，供 GameManager 在场景加载后应用）
var _pending_load_data: Dictionary = {}


# ============================================================
# 生命周期函数
# ============================================================

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_config()
	_ensure_save_dir()
	print("[SaveManager] 存档系统就绪 — 版本:%s  槽位数:%d" % [_save_version, _max_slots])


# ============================================================
# 配置加载
# ============================================================

func _load_config() -> void:
	## 从 save_config.json 读取版本号和最大槽位数
	if not FileAccess.file_exists(SAVE_CONFIG_PATH):
		push_warning("[SaveManager] 未找到 save_config.json，使用默认配置")
		return

	var file: FileAccess = FileAccess.open(SAVE_CONFIG_PATH, FileAccess.READ)
	if not file:
		return

	var json_text: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var err: Error = json.parse(json_text)
	if err == OK:
		var data: Variant = json.get_data()
		_save_version = data.get("version", _save_version)
		_max_slots = data.get("max_slots", _max_slots)
	else:
		push_warning("[SaveManager] save_config.json 解析失败，使用默认配置")


func _ensure_save_dir() -> void:
	## 确保存档目录存在
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		var err: Error = DirAccess.make_dir_recursive_absolute(SAVE_DIR)
		if err != OK:
			push_error("[SaveManager] 无法创建存档目录: %s (错误码: %d)" % [SAVE_DIR, err])


# ============================================================
# 路径工具
# ============================================================

func _get_save_path(slot: int) -> String:
	## 获取指定槽位的完整存档文件路径
	return SAVE_DIR + (SAVE_FILE_TEMPLATE % slot)


# ============================================================
# 核心接口：保存
# ============================================================

func save_game(slot: int, data: Dictionary) -> bool:
	## 保存游戏到指定槽位，返回是否成功
	if slot < 0 or slot >= _max_slots:
		push_error("[SaveManager] 槽位 %d 超出范围 [0, %d)" % [slot, _max_slots])
		return false

	_ensure_save_dir()

	# 写入版本号和时间戳
	data["version"] = _save_version
	data["timestamp"] = Time.get_unix_time_from_system()

	var json_text: String = JSON.stringify(data, "\t")
	var path: String = _get_save_path(slot)

	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("[SaveManager] 无法写入存档: %s" % path)
		return false

	file.store_string(json_text)
	file.close()

	print("[SaveManager] 存档已保存到槽位 %d (大小: %d 字节)" % [slot, json_text.length()])
	return true


# ============================================================
# 核心接口：读取
# ============================================================

func load_game(slot: int) -> Dictionary:
	## 从指定槽位读取存档，返回完整数据字典；槽位为空时返回 {}
	if not has_save(slot):
		return {}

	var path: String = _get_save_path(slot)
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}

	var json_text: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var err: Error = json.parse(json_text)
	if err != OK:
		push_error("[SaveManager] 存档解析失败: 槽位 %d (行:%d 消息:%s)" % [slot, json.get_error_line(), json.get_error_message()])
		return {}

	var data: Variant = json.get_data()
	if typeof(data) != TYPE_DICTIONARY:
		return {}

	# 版本校验（仅警告，不阻止加载）
	var save_ver: String = data.get("version", "")
	if save_ver != _save_version and not save_ver.is_empty():
		push_warning("[SaveManager] 存档版本不匹配: 存档=%s  当前=%s，尝试兼容加载" % [save_ver, _save_version])

	print("[SaveManager] 存档已读取: 槽位 %d" % slot)
	return data


# ============================================================
# 核心接口：删除 / 检测 / 元数据
# ============================================================

func delete_save(slot: int) -> void:
	## 删除指定槽位的存档文件
	var path: String = _get_save_path(slot)
	if FileAccess.file_exists(path):
		var err: Error = DirAccess.remove_absolute(path)
		if err == OK:
			print("[SaveManager] 存档已删除: 槽位 %d" % slot)
		else:
			push_error("[SaveManager] 删除存档失败: %s" % path)


func has_save(slot: int) -> bool:
	## 检查指定槽位是否有存档文件
	return FileAccess.file_exists(_get_save_path(slot))


func get_slot_info(slot: int) -> Dictionary:
	## 获取槽位元数据（轻量级，仅读取关键字段）
	if not has_save(slot):
		return {"has_save": false}

	var data: Dictionary = load_game(slot)
	if data.is_empty():
		return {"has_save": false}

	var player_data: Dictionary = data.get("player", {})
	var game_data: Dictionary = data.get("game", {})

	return {
		"has_save": true,
		"timestamp": data.get("timestamp", 0),
		"play_time": data.get("play_time", 0.0),
		"level": player_data.get("level", 1),
		"wave": game_data.get("wave", 1),
	}


# ============================================================
# 待恢复数据管理（跨场景传递）
# ============================================================

func set_pending_load(data: Dictionary) -> void:
	## 设置待恢复的存档数据（由 GameManager 在切场景前调用）
	_pending_load_data = data


func get_pending_load() -> Dictionary:
	## 获取待恢复的存档数据（由 GameManager 在场景加载后调用）
	return _pending_load_data


func clear_pending_load() -> void:
	## 清除待恢复数据
	_pending_load_data.clear()
