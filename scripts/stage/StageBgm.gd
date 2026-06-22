# 2026-06-14: ステージ共通のBGM再生を扱う。
class_name StageBgm
extends Node

@export var enabled := true # BGMを再生するかどうか。
@export_file("*.wav") var bgm_path := "res://assets/bgm/memory_bite_loop_02.wav" # 再生するBGM。
@export var volume_db := -15.0 # BGMの音量。
@export_range(0.0, 18.0, 0.5) var duck_db := 6.0 # 重要SE再生時に下げる音量。
@export_range(0.0, 1.0, 0.01) var duck_hold_time := 0.16 # 音量を下げたまま保持する時間。
@export_range(0.0, 1.0, 0.01) var duck_recover_time := 0.18 # 通常音量へ戻す時間。

var player: AudioStreamPlayer # 実際にBGMを鳴らすプレイヤー。
var duck_tween: Tween # BGMダッキング用のTween。

# BGMを読み込んでループ再生する。
func setup() -> void:
	if not enabled or DisplayServer.get_name() == "headless":
		return
	var stream := AudioStreamWAV.load_from_file(bgm_path)
	if stream == null:
		push_error("Failed to load bgm: %s" % bgm_path)
		return
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = stream.data.size() / 2

	player = AudioStreamPlayer.new()
	player.name = "BgmPlayer"
	player.stream = stream
	player.volume_db = volume_db
	add_child(player)
	player.play()

# BGMを停止する。
func stop() -> void:
	if player != null:
		player.stop()

# 重要SEが聞こえやすいようにBGMを短く下げる。
func duck() -> void:
	if player == null:
		return
	if duck_tween != null:
		duck_tween.kill()
	player.volume_db = volume_db - duck_db
	duck_tween = create_tween()
	duck_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	duck_tween.tween_interval(duck_hold_time)
	duck_tween.tween_property(player, "volume_db", volume_db, duck_recover_time)
