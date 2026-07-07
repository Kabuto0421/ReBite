# 2026-07-06: ゲーム全体のBGM/SE音量を保持する。
class_name AudioSettings
extends RefCounted

const CONFIG_PATH := "user://audio_settings.cfg"
const SECTION := "audio"
const DEFAULT_BGM_VOLUME := 1.0
const DEFAULT_SE_VOLUME := 1.0

static var bgm_volume := DEFAULT_BGM_VOLUME
static var se_volume := DEFAULT_SE_VOLUME
static var loaded := false

# 保存済みの音量設定を読み込む。
static func load_settings() -> void:
	if loaded:
		return
	loaded = true
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return
	bgm_volume = clampf(float(config.get_value(SECTION, "bgm_volume", DEFAULT_BGM_VOLUME)), 0.0, 1.0)
	se_volume = clampf(float(config.get_value(SECTION, "se_volume", DEFAULT_SE_VOLUME)), 0.0, 1.0)

# 現在の音量設定を保存する。
static func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION, "bgm_volume", bgm_volume)
	config.set_value(SECTION, "se_volume", se_volume)
	config.save(CONFIG_PATH)

# BGM音量を0から1の範囲で設定する。
static func set_bgm_volume(value: float, save := true) -> void:
	load_settings()
	bgm_volume = clampf(value, 0.0, 1.0)
	if save:
		save_settings()

# SE音量を0から1の範囲で設定する。
static func set_se_volume(value: float, save := true) -> void:
	load_settings()
	se_volume = clampf(value, 0.0, 1.0)
	if save:
		save_settings()

# BGMの基準dBへユーザー音量を反映する。
static func apply_bgm_volume_db(base_db: float) -> float:
	load_settings()
	return _apply_linear_volume(base_db, bgm_volume)

# SEの基準dBへユーザー音量を反映する。
static func apply_se_volume_db(base_db: float) -> float:
	load_settings()
	return _apply_linear_volume(base_db, se_volume)

# 0の時だけ実質ミュート、それ以外はGodot標準のlinear_to_dbで変換する。
static func _apply_linear_volume(base_db: float, value: float) -> float:
	if value <= 0.001:
		return -80.0
	return base_db + linear_to_db(value)
