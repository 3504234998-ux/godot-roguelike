extends Node2D
## 武器瞄准控制器
## 负责：武器朝向鼠标旋转 / 提供射击方向 / 管理瞄准箭头 / 枪口位置


# ============================================================
# 导出变量（可在编辑器中调整）
# ============================================================

## 枪口距玩家中心的偏移距离（像素）
@export var muzzle_distance: float = 30.0


# ============================================================
# 内部状态变量
# ============================================================

## 当前瞄准方向（归一化向量，每帧更新）
var _aim_direction: Vector2 = Vector2.RIGHT

## 玩家节点引用
var _player: CharacterBody2D = null


# ============================================================
# 节点引用（@onready）
# ============================================================

@onready var _muzzle: Marker2D = $Muzzle


# ============================================================
# 生命周期函数
# ============================================================

func _ready() -> void:
	_player = get_parent() as CharacterBody2D

	# 枪口标记定位在武器前方
	_muzzle.position = Vector2(muzzle_distance, 0)

	print("[PlayerAim] 武器瞄准系统就绪")


func _process(_delta: float) -> void:
	# 每帧更新瞄准方向并旋转武器
	_update_aim()


# ============================================================
# 瞄准逻辑
# ============================================================

func _update_aim() -> void:
	## 计算武器朝向鼠标的方向并旋转 WeaponPivot
	if not _player:
		return

	var mouse_pos: Vector2 = get_global_mouse_position()
	var dir: Vector2 = mouse_pos - global_position

	# 鼠标与玩家重合时保持上次方向
	if dir.length_squared() > 0.01:
		_aim_direction = dir.normalized()

	rotation = _aim_direction.angle()


# ============================================================
# 公共接口
# ============================================================

func get_aim_direction() -> Vector2:
	## 获取当前瞄准方向（供攻击系统使用）
	return _aim_direction


func get_muzzle_position() -> Vector2:
	## 获取枪口全局位置（供子弹生成使用）
	return _muzzle.global_position
