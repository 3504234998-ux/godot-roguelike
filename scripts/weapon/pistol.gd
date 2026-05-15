extends WeaponBase
## 手枪 —— 稳定单发，精准射击


func fire(aim_dir: Vector2) -> void:
	_spawn_spread(aim_dir, _get_muzzle_position(), bullet_count, spread_angle, damage, pierce_count, bullet_speed)
