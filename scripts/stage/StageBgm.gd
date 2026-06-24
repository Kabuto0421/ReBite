# 2026-06-14: ステージ共通のBGM再生を扱う。
class_name StageBgm
extends Node

@export var enabled := true # BGMを再生するかどうか。
@export_file("*.wav", "*.ogg") var bgm_path := "res://assets/bgm/memory_bite_loop_02.wav" # 再生するBGM。
@export var volume_db := -15.0 # BGMの音量。
@export var bus_name := &"Master" # BGMを出力するAudio Bus。
@export_range(0.0, 18.0, 0.5) var duck_db := 6.0 # 重要SE再生時に下げる音量。
@export_range(0.0, 1.0, 0.01) var duck_hold_time := 0.16 # 音量を下げたまま保持する時間。
@export_range(0.0, 1.0, 0.01) var duck_recover_time := 0.18 # 通常音量へ戻す時間。

var player: AudioStreamPlayer # 実際にBGMを鳴らすプレイヤー。
var duck_tween: Tween # BGMダッキング用のTween。
var active_volume_db := -15.0 # 現在再生中の曲が戻る基準音量。

# BGMプレイヤーを作り、指定されている場合は既定曲を再生する。
func setup(autoplay: bool = true) -> void:
	if not enabled or DisplayServer.get_name() == "headless":
		return
	_ensure_player()
	if autoplay:
		play_track(bgm_path, true, volume_db)

# WAVまたはOggの曲を読み込み、ループ設定と音量を適用して再生する。
func play_track(path: String, should_loop: bool = true, track_volume_db: float = 999.0) -> void:
	if not enabled or DisplayServer.get_name() == "headless":
		return
	_ensure_player()
	var loaded_stream := load(path) as AudioStream
	var stream := loaded_stream.duplicate() as AudioStream if loaded_stream != null else null
	if stream == null:
		push_error("Failed to load bgm: %s" % path)
		return
	_set_stream_loop(stream, should_loop)
	player.stream = stream
	active_volume_db = volume_db if track_volume_db >= 900.0 else track_volume_db
	player.volume_db = active_volume_db
	player.play()

# BGMを停止する。
func stop() -> void:
	if player != null:
		player.stop()

# 現在および今後再生するBGMの出力Busを切り替える。
func set_output_bus(next_bus_name: StringName) -> void:
	bus_name = next_bus_name
	if player != null:
		player.bus = bus_name

# AudioStreamPlayerを必要な時に一度だけ生成する。
func _ensure_player() -> void:
	if player != null:
		return
	player = AudioStreamPlayer.new()
	player.name = "BgmPlayer"
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	player.bus = bus_name
	add_child(player)

# 音源形式ごとのループ設定を統一する。
func _set_stream_loop(stream: AudioStream, should_loop: bool) -> void:
	if stream is AudioStreamOggVorbis:
		stream.loop = should_loop
		stream.loop_offset = 0.0
	elif stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD if should_loop else AudioStreamWAV.LOOP_DISABLED
		stream.loop_begin = 0
		stream.loop_end = int(stream.get_length() * stream.mix_rate)

# 重要SEが聞こえやすいようにBGMを短く下げる。
func duck() -> void:
	if player == null:
		return
	if duck_tween != null:
		duck_tween.kill()
	player.volume_db = active_volume_db - duck_db
	duck_tween = create_tween()
	duck_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	duck_tween.tween_interval(duck_hold_time)
	duck_tween.tween_property(player, "volume_db", active_volume_db, duck_recover_time)
