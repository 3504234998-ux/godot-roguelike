extends WeaponBase
## 散弹枪 —— 扇形散射，近距离高伤


func fire(aim_dir: Vector2) -> void:
	_spawn_spread(aim_dir, _get_muzzle_position(), bullet_count, spread_angle, damage, pierce_count, bullet_speed)
