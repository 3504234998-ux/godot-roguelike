extends Node
## 玩家生命值组件
## 负责：HP管理 / 受到伤害 / 死亡处理


# ============================================================
# 信号
# ============================================================

## 血量变化信号（当前HP, 最大HP）
signal health_changed(current_hp: int, max_hp: int)

## 玩家死亡信号
signal player_died


# ============================================================
# 导出变量（可在编辑器中调整）
# ============================================================

## 最大生命值
@export var max_hp: int = 100


# ============================================================
# 内部状态变量
# ============================================================

## 当前生命值
var current_hp: int


# ============================================================
# 生命周期函数
# ============================================================

func _ready() -> void:
	current_hp = max_hp
	# 初始广播一次血量状态，触发 UI 首次更新
	health_changed.emit(current_hp, max_hp)
	print("[PlayerHealth] 血量系统就绪，HP: %d/%d" % [current_hp, max_hp])


# ============================================================
# 伤害与治疗
# ============================================================

func take_damage(amount: int) -> void:
	## 受到伤害（由敌人等攻击来源调用）
	current_hp = maxi(current_hp - amount, 0)
	health_changed.emit(current_hp, max_hp)
	print("[PlayerHealth] 受到 %d 点伤害，剩余 HP: %d/%d" % [amount, current_hp, max_hp])

	if current_hp <= 0:
		_die()


func heal(amount: int) -> void:
	## 恢复生命值
	current_hp = mini(current_hp + amount, max_hp)
	health_changed.emit(current_hp, max_hp)
	print("[PlayerHealth] 恢复 %d 点生命，当前 HP: %d/%d" % [amount, current_hp, max_hp])


func _die() -> void:
	## 玩家死亡
	print("[PlayerHealth] 玩家死亡！")
	player_died.emit()
	# TODO: 后续实现死亡重开逻辑
	get_parent().queue_free()


# ============================================================
# 公共接口
# ============================================================

func get_hp_ratio() -> float:
	## 获取当前血量比例 [0.0, 1.0]
	return clampf(float(current_hp) / float(max_hp), 0.0, 1.0)


func is_alive() -> bool:
	## 检查是否存活
	return current_hp > 0
