extends Node
## 音效管理器（Autoload 单例）
## 负责：统一管理所有音效播放 / 音量控制
## 当前为占位实现（无音频文件时静默跳过）


# ============================================================
# 导出变量
# ============================================================

## 主音量（0.0 ~ 1.0）
@export var master_volume: float = 0.8

## 音效音量
@export var sfx_volume: float = 1.0


# ============================================================
# 内部状态变量
# ============================================================

## 音效是否启用（无音频文件时关闭）
var _audio_enabled: bool = false


# ============================================================
# 生命周期函数
# ============================================================

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 检测音频文件是否存在
	_check_audio_files()
	print("[AudioManager] 音效管理器就绪 — 音频%s" % ("已启用" if _audio_enabled else "未启用（占位模式）"))


# ============================================================
# 音量控制
# ============================================================

func get_master_volume() -> float:
	## 获取主音量（0.0 ~ 1.0）
	return master_volume


func set_master_volume(volume: float) -> void:
	## 设置主音量
	master_volume = clampf(volume, 0.0, 1.0)


# ============================================================
# 内部函数
# ============================================================

func _check_audio_files() -> void:
	## 检查音频资源是否存在
	var test_paths := [
		"res://assets/audio/hit.wav",
		"res://assets/audio/death.wav",
		"res://assets/audio/hurt.wav",
	]
	for path in test_paths:
		if FileAccess.file_exists(path):
			_audio_enabled = true
			return


# ============================================================
# 音效播放接口
# ============================================================

func play_hit() -> void:
	## 子弹命中音效
	if _audio_enabled:
		_play_sfx("res://assets/audio/hit.wav")


func play_enemy_death() -> void:
	## 敌人死亡音效
	if _audio_enabled:
		_play_sfx("res://assets/audio/death.wav")


func play_player_hurt() -> void:
	## 玩家受伤音效
	if _audio_enabled:
		_play_sfx("res://assets/audio/hurt.wav")


func play_level_up() -> void:
	## 升级音效
	if _audio_enabled:
		_play_sfx("res://assets/audio/level_up.wav")


func play_boss_dash() -> void:
	## Boss 冲撞音效
	if _audio_enabled:
		_play_sfx("res://assets/audio/boss_dash.wav")


func play_boss_death() -> void:
	## Boss 死亡音效
	if _audio_enabled:
		_play_sfx("res://assets/audio/boss_death.wav")


func play_exp_pickup() -> void:
	## 经验拾取音效
	if _audio_enabled:
		_play_sfx("res://assets/audio/exp_pickup.wav")


# ============================================================
# 内部播放
# ============================================================

func _play_sfx(path: String) -> void:
	## 加载并播放音效
	if not ResourceLoader.exists(path):
		return

	var stream = load(path)
	if stream:
		var player := AudioStreamPlayer.new()
		add_child(player)
		player.stream = stream
		player.volume_db = linear_to_db(sfx_volume * master_volume)
		player.finished.connect(player.queue_free)
		player.play()
