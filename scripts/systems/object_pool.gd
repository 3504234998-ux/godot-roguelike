class_name ObjectPool
extends Node
## 通用对象池
## 负责：预实例化 / 获取对象 / 回收对象 / 自动扩容
## 替代频繁 instantiate() + queue_free()，减少 GC 压力


# ============================================================
# 信号
# ============================================================

## 对象被取出
signal object_acquired(obj: Node)

## 对象被回收
signal object_released(obj: Node)

## 池自动扩容
signal pool_expanded(new_size: int)


# ============================================================
# 内部状态变量
# ============================================================

## 对象数组（包含活跃与非活跃对象）
var _pool: Array[Node] = []

## 场景模板
var _scene: PackedScene = null

## 是否自动扩容
var _auto_expand: bool = true

## 最大容量（0 = 无上限）
var _max_size: int = 0


# ============================================================
# 初始化
# ============================================================

func setup(scene: PackedScene, initial_size: int, auto_expand: bool = true, max_size: int = 0) -> void:
	## 配置对象池并预填充
	_scene = scene
	_auto_expand = auto_expand
	_max_size = max_size

	for i in range(initial_size):
		_create_one()


func _create_one() -> Node:
	## 创建单个对象并加入池（禁用状态）
	var obj: Node = _scene.instantiate()
	obj.process_mode = Node.PROCESS_MODE_DISABLED
	_disable_all(obj)
	add_child(obj)
	_pool.append(obj)
	return obj


# ============================================================
# 获取与回收
# ============================================================

func acquire() -> Node:
	## 从池中获取一个可用对象（调用方需用 reparent() 移入目标场景）
	# 先找已回收的（反向遍历以便安全移除过期条目）
	for i in range(_pool.size() - 1, -1, -1):
		var obj: Node = _pool[i]
		# 清理已被外部释放的过期引用（例如 scene reload 后）
		if not is_instance_valid(obj):
			_pool.remove_at(i)
			continue
		if obj.process_mode == Node.PROCESS_MODE_DISABLED:
			obj.process_mode = Node.PROCESS_MODE_INHERIT
			_enable_all(obj)
			object_acquired.emit(obj)
			return obj

	# 自动扩容
	if _auto_expand and (_max_size == 0 or _pool.size() < _max_size):
		var obj: Node = _create_one()
		obj.process_mode = Node.PROCESS_MODE_INHERIT
		_enable_all(obj)
		pool_expanded.emit(_pool.size())
		object_acquired.emit(obj)
		return obj

	push_warning("[ObjectPool] 池已耗尽 (size=%d)，无法获取对象" % _pool.size())
	return null


func release(obj: Node) -> void:
	## 回收对象到池中
	if obj == null:
		return
	# 拒绝已释放的对象
	if not is_instance_valid(obj):
		return

	obj.process_mode = Node.PROCESS_MODE_DISABLED
	_disable_all(obj)

	# 通知对象即将回池（若对象有 _on_pool_release 方法）
	if obj.has_method("_on_pool_release"):
		obj._on_pool_release()

	# 从当前父节点移除，归还到池
	if obj.get_parent():
		obj.get_parent().remove_child(obj)
	add_child(obj)

	object_released.emit(obj)


# ============================================================
# 状态开关
# ============================================================

func _disable_all(obj: Node) -> void:
	## 递归禁用节点的所有碰撞与可见性
	_disable_node(obj)
	for child in obj.find_children("*"):
		_disable_node(child)


func _enable_all(obj: Node) -> void:
	## 递归启用节点的所有碰撞与可见性
	_enable_node(obj)
	for child in obj.find_children("*"):
		_enable_node(child)


func _disable_node(node: Node) -> void:
	if node is CollisionShape2D or node is CollisionPolygon2D:
		node.disabled = true
	elif node is Area2D:
		node.monitoring = false
		node.monitorable = false
	if node is CanvasItem:
		node.visible = false


func _enable_node(node: Node) -> void:
	if node is CollisionShape2D or node is CollisionPolygon2D:
		node.disabled = false
	elif node is Area2D:
		node.monitoring = true
		node.monitorable = true
	if node is CanvasItem:
		node.visible = true


# ============================================================
# 查询接口
# ============================================================

func get_available_count() -> int:
	## 获取当前可回收对象数量
	var count: int = 0
	for i in range(_pool.size() - 1, -1, -1):
		var obj: Node = _pool[i]
		if not is_instance_valid(obj):
			_pool.remove_at(i)
			continue
		if obj.process_mode == Node.PROCESS_MODE_DISABLED:
			count += 1
	return count


func get_active_count() -> int:
	## 获取当前活跃（已取出）对象数量
	var valid: int = 0
	var disabled: int = 0
	for i in range(_pool.size() - 1, -1, -1):
		var obj: Node = _pool[i]
		if not is_instance_valid(obj):
			_pool.remove_at(i)
			continue
		valid += 1
		if obj.process_mode == Node.PROCESS_MODE_DISABLED:
			disabled += 1
	return valid - disabled


func get_total_size() -> int:
	## 获取池中有效对象总数（排除已释放的）
	_cleanup_stale()
	return _pool.size()


func _cleanup_stale() -> void:
	## 清除所有过期引用
	for i in range(_pool.size() - 1, -1, -1):
		if not is_instance_valid(_pool[i]):
			_pool.remove_at(i)
