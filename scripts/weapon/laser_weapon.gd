extends WeaponBase
## 激光枪 —— 高速穿透，持续输出


func fire(aim_dir: Vector2) -> void:
	_spawn_bullet(aim_dir, _get_muzzle_position(), damage, pierce_count, bullet_speed)
