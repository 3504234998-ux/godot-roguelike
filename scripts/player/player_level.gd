extends Node
## 玩家等级系统
## 负责：经验累积 / 自动升级 / 升级后强化属性


# ============================================================
# 信号
# ============================================================

## 升级信号（新等级）
signal leveled_up(new_level: int)

## 经验变化信号（当前经验, 升级所需经验）
signal exp_changed(current_exp: int, exp_to_next: int)

## 升级可用信号（通知 UpgradeManager 弹出三选一 UI）
signal upgrade_available(new_level: int)


# ============================================================
# 导出变量（可在编辑器中调整）
# ============================================================

## 初始升到2级所需经验
@export var base_exp_required: int = 50

## 每级经验需求倍率（1.5 = 每级需要前一级的 1.5 倍经验）
@export var exp_growth_rate: float = 1.5

# ============================================================
# 内部状态变量
# ============================================================

## 当前累积经验
var current_exp: int = 0

## 当前等级
var current_level: int = 1


# ============================================================
# 生命周期函数
# ============================================================

func _ready() -> void:
	# 从 game_balance.json 读取平衡参数（若存在则覆盖默认值）
	if DataManager.is_loaded():
		var balance: Dictionary = DataManager.get_balance()
		var lv: Dictionary = balance.get("leveling", {})
		if not lv.is_empty():
			base_exp_required = lv.get("base_exp_required", base_exp_required)
			exp_growth_rate = lv.get("exp_growth_rate", exp_growth_rate)
	print("[PlayerLevel] 等级系统就绪，等级: %d  升级所需: %d 经验" % [current_level, _exp_to_next()])


# ============================================================
# 经验系统
# ============================================================

func add_exp(amount: int) -> void:
	## 获得经验（由经验球调用）
	current_exp += amount
	var needed: int = _exp_to_next()
	print("[PlayerLevel] +%d 经验  [%d/%d]" % [amount, current_exp, needed])

	# 循环升级（一次获得大量经验时可能连升多级）
	while current_exp >= needed:
		current_exp -= needed
		_level_up()
		needed = _exp_to_next()

	# 通知 UI 经验变化（升级后 needed 已更新）
	exp_changed.emit(current_exp, needed)


func _exp_to_next() -> int:
	## 计算当前等级升到下一级需要的经验
	# 公式：base * growth_rate^(level-1)
	return int(base_exp_required * pow(exp_growth_rate, current_level - 1))


# ============================================================
# 升级系统
# ============================================================

func _level_up() -> void:
	## 升级：增加等级 → 发射信号让 UpgradeManager 弹出三选一 UI
	current_level += 1
	print("[PlayerLevel] ★ 升级！当前等级: %d  下級需要: %d 经验" % [current_level, _exp_to_next()])

	# 发射升级信号（供 HUD 更新等级显示）
	leveled_up.emit(current_level)

	# 发射升级可用信号（供 UpgradeManager 暂停游戏并弹出三选一 UI）
	upgrade_available.emit(current_level)

	# 升级音效
	AudioManager.play_level_up()


# ============================================================
# 公共接口
# ============================================================

func get_level() -> int:
	## 获取当前等级
	return current_level


func get_exp_ratio() -> float:
	## 获取当前经验进度比例 [0.0, 1.0]，供经验条 UI 使用
	var needed: int = _exp_to_next()
	if needed <= 0:
		return 1.0
	return clampf(float(current_exp) / float(needed), 0.0, 1.0)


func get_exp_to_next() -> int:
	## 获取升到下一级需要的总经验
	return _exp_to_next()
