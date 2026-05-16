extends Node
## 武器管理器
## 负责：管理多武器槽位 / 武器切换 / 冷却调度 / 升级代理


# ============================================================
# 信号
# ============================================================

# 预加载武器脚本（无需 class_name，避免加载顺序问题）
const _PistolScript := preload("res://scripts/weapon/pistol.gd")
const _ShotgunScript := preload("res://scripts/weapon/shotgun.gd")
const _LaserWeaponScript := preload("res://scripts/weapon/laser_weapon.gd")

signal weapon_changed(weapon_id: String, weapon_name: String)


# ============================================================
# 导出变量
# ============================================================

@export var bullet_scene: PackedScene


# ============================================================
# 内部变量
# ============================================================

var _weapon_slots: Array[WeaponBase] = [null, null, null]
var _current_index: int = 0
var _weapon_pivot: Node2D = null
var _switch_debounce: float = 0.0


# ============================================================
# 升级兼容属性
# ============================================================

var attack_interval: float:
	get:
		if _get_current_weapon():
			return 1.0 / maxf(_get_current_weapon().fire_rate, 0.1)
		return 0.5
	set(v):
		if _get_current_weapon():
			_get_current_weapon().fire_rate = 1.0 / maxf(v, 0.05)

var current_damage: int:
	get:
		if _get_current_weapon():
			return _get_current_weapon().damage
		return 10
	set(v):
		for w in _weapon_slots:
			if w:
				w.damage = v

var bullet_count: int:
	get:
		if _get_current_weapon():
			return _get_current_weapon().bullet_count
		return 1
	set(v):
		if _get_current_weapon():
			_get_current_weapon().bullet_count = maxi(v, 1)

var pierce_count: int:
	get:
		if _get_current_weapon():
			return _get_current_weapon().pierce_count
		return 0
	set(v):
		if _get_current_weapon():
			_get_current_weapon().pierce_count = v

var current_bullet_speed: float:
	get:
		if _get_current_weapon():
			return _get_current_weapon().bullet_speed
		return 500.0
	set(v):
		if _get_current_weapon():
			_get_current_weapon().bullet_speed = v


# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	if bullet_scene:
		ObjectPoolManager.init_bullet_pool(bullet_scene)

	_weapon_pivot = get_parent().get_node_or_null("WeaponPivot")
	if not _weapon_pivot:
		push_error("[WeaponManager] 未找到 WeaponPivot 节点！")

	var cfg: Dictionary = _load_weapon_config("pistol")
	if not cfg.is_empty():
		_equip_weapon(0, cfg)

	print("[WeaponManager] 武器系统就绪 — 当前: %s" % _get_current_name())


func _process(delta: float) -> void:
	_switch_debounce -= delta
	if _switch_debounce <= 0.0:
		_check_switch_input()

	if _get_current_weapon():
		_get_current_weapon().update_cooldown(delta)
		_get_current_weapon().try_fire()


# ============================================================
# 武器切换
# ============================================================

func _check_switch_input() -> void:
	for i in range(3):
		if Input.is_key_pressed(KEY_1 + i):
			_switch_to(i)

	# 测试快捷键：Q = 获得散弹枪，E = 获得激光枪
	if Input.is_key_pressed(KEY_Q):
		acquire_weapon("shotgun")
	if Input.is_key_pressed(KEY_E):
		acquire_weapon("laser_weapon")


func _switch_to(slot: int) -> void:
	if slot == _current_index:
		return
	if slot < 0 or slot >= _weapon_slots.size():
		return
	var weapon: WeaponBase = _weapon_slots[slot]
	if not weapon:
		return
	_current_index = slot
	_switch_debounce = 0.2
	weapon_changed.emit(weapon.weapon_id, weapon.weapon_name)
	print("[WeaponManager] 切换到: [%s] %s" % [weapon.weapon_id, weapon.weapon_name])


# ============================================================
# 武器配置加载
# ============================================================

func _load_weapon_config(weapon_id: String) -> Dictionary:
	if DataManager.is_loaded():
		var cfg: Dictionary = DataManager.get_weapon_data(weapon_id)
		if not cfg.is_empty():
			return cfg
	return _get_fallback_config(weapon_id)


func _get_fallback_config(weapon_id: String) -> Dictionary:
	match weapon_id:
		"pistol":
			return {"id":"pistol","name":"手枪","damage":20,"fire_rate":2.5,"bullet_count":1,"spread_angle":3.0,"pierce_count":0,"bullet_speed":600.0,"weapon_class":"Pistol","description":"稳定单发"}
		"shotgun":
			return {"id":"shotgun","name":"散弹枪","damage":12,"fire_rate":1.2,"bullet_count":5,"spread_angle":40.0,"pierce_count":1,"bullet_speed":450.0,"weapon_class":"Shotgun","description":"扇形散射"}
		"laser_weapon":
			return {"id":"laser_weapon","name":"激光枪","damage":8,"fire_rate":8.0,"bullet_count":1,"spread_angle":1.0,"pierce_count":5,"bullet_speed":800.0,"weapon_class":"LaserWeapon","description":"高速穿透"}
	return {}


# ============================================================
# 武器槽位管理
# ============================================================

func _equip_weapon(slot: int, config: Dictionary) -> void:
	if slot < 0 or slot >= _weapon_slots.size():
		return
	if _weapon_slots[slot]:
		_weapon_slots[slot].queue_free()
		_weapon_slots[slot] = null

	var weapon_class: String = config.get("weapon_class", "Pistol")
	var weapon: WeaponBase = _create_weapon_instance(weapon_class)
	if not weapon:
		return

	weapon.name = config.get("id", "weapon_%d" % slot)
	add_child(weapon)
	weapon.setup(config, _weapon_pivot, bullet_scene)
	_weapon_slots[slot] = weapon
	_current_index = slot


func _create_weapon_instance(weapon_class: String) -> WeaponBase:
	match weapon_class:
		"Pistol":
			return _PistolScript.new()
		"Shotgun":
			return _ShotgunScript.new()
		"LaserWeapon":
			return _LaserWeaponScript.new()
	return null


func _get_current_weapon() -> WeaponBase:
	return _weapon_slots[_current_index]


func _get_current_name() -> String:
	var w: WeaponBase = _get_current_weapon()
	if w:
		return w.weapon_name
	return "无"


# ============================================================
# 公共接口
# ============================================================

func get_weapon_info() -> Dictionary:
	var w: WeaponBase = _get_current_weapon()
	if not w:
		return {}
	return {"id":w.weapon_id,"name":w.weapon_name,"damage":w.damage,"fire_rate":w.fire_rate,"bullet_count":w.bullet_count}


func get_weapon_list() -> Array:
	var list: Array = []
	for i in range(_weapon_slots.size()):
		var w: WeaponBase = _weapon_slots[i]
		var entry := {
			"slot": i + 1,
			"name": w.weapon_name if w else "空",
			"equipped": i == _current_index,
		}
		list.append(entry)
	return list


func acquire_weapon(weapon_id: String) -> void:
	var cfg: Dictionary = _load_weapon_config(weapon_id)
	if cfg.is_empty():
		return
	for i in range(_weapon_slots.size()):
		if not _weapon_slots[i]:
			_equip_weapon(i, cfg)
			print("[WeaponManager] %s 装备到槽位 %d" % [cfg["name"], i + 1])
			return
	var old: WeaponBase = _weapon_slots[_current_index]
	old.queue_free()
	_equip_weapon(_current_index, cfg)


func set_attack_interval(interval: float) -> void:
	if _get_current_weapon():
		_get_current_weapon().fire_rate = 1.0 / maxf(interval, 0.05)


func increase_damage(amount: int) -> void:
	for w in _weapon_slots:
		if w:
			w.damage += amount
	print("[WeaponManager] 所有武器伤害 +%d" % amount)


# ============================================================
# 存档接口
# ============================================================

func get_weapon_save_data() -> Array:
	## 获取所有武器槽位的存档数据（null 表示空槽位）
	var data: Array = []
	for w in _weapon_slots:
		if w:
			data.append({
				"id": w.weapon_id,
				"damage": w.damage,
				"fire_rate": w.fire_rate,
				"bullet_count": w.bullet_count,
				"pierce_count": w.pierce_count,
				"bullet_speed": w.bullet_speed,
			})
		else:
			data.append(null)
	return data


func restore_weapons(weapons_data: Array) -> void:
	## 从存档数据恢复武器槽位
	# 先清除所有现有武器
	for i in range(_weapon_slots.size()):
		if _weapon_slots[i]:
			_weapon_slots[i].queue_free()
			_weapon_slots[i] = null

	# 按存档数据重新装备
	for i in range(mini(weapons_data.size(), _weapon_slots.size())):
		var wdata = weapons_data[i]
		if wdata == null or typeof(wdata) != TYPE_DICTIONARY:
			continue
		var weapon_id: String = wdata.get("id", "")
		if weapon_id.is_empty():
			continue

		# 加载基础配置（获取 weapon_class 等元数据）
		var cfg: Dictionary = _load_weapon_config(weapon_id)
		if cfg.is_empty():
			continue

		# 用存档数据覆盖武器属性
		cfg["damage"] = wdata.get("damage", cfg.get("damage", 10))
		cfg["fire_rate"] = wdata.get("fire_rate", cfg.get("fire_rate", 2.0))
		cfg["bullet_count"] = wdata.get("bullet_count", cfg.get("bullet_count", 1))
		cfg["pierce_count"] = wdata.get("pierce_count", cfg.get("pierce_count", 0))
		cfg["bullet_speed"] = wdata.get("bullet_speed", cfg.get("bullet_speed", 500.0))

		_equip_weapon(i, cfg)

	# 切换到第一个有效武器
	for i in range(_weapon_slots.size()):
		if _weapon_slots[i]:
			_current_index = i
			break

	print("[WeaponManager] 已从存档恢复 %d 个武器" % weapons_data.size())
