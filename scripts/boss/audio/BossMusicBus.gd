# 2026-06-23: ボス戦BGM専用バスへInspector調整可能な10バンドEQを構築する。
class_name BossMusicBus
extends Node

@export var bus_name := &"BossMusic" # AudioServerへ作成する専用バス名。
@export var bus_volume_db := 0.0 # EQ後のバス全体音量。

@export_group("EQ Gain dB")
@export_range(-12.0, 12.0, 0.5) var hz_31 := -4.0 # 超低域の整理量。
@export_range(-12.0, 12.0, 0.5) var hz_62 := -3.0 # 低域の整理量。
@export_range(-12.0, 12.0, 0.5) var hz_125 := -1.0 # ベース帯域の補正量。
@export_range(-12.0, 12.0, 0.5) var hz_250 := 2.0 # 低中域の明瞭度。
@export_range(-12.0, 12.0, 0.5) var hz_500 := 4.0 # 中域の明瞭度。
@export_range(-12.0, 12.0, 0.5) var hz_1000 := 5.0 # 主旋律の存在感。
@export_range(-12.0, 12.0, 0.5) var hz_2000 := 7.0 # 主旋律とアタックの存在感。
@export_range(-12.0, 12.0, 0.5) var hz_4000 := 7.0 # 輪郭の補正量。
@export_range(-12.0, 12.0, 0.5) var hz_8000 := 4.0 # 高域の抜け。
@export_range(-12.0, 12.0, 0.5) var hz_16000 := 1.0 # 最上域の補正量。

# 専用Audio BusとEQ10を作成または更新する。
func setup() -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		AudioServer.add_bus()
		bus_index = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(bus_index, bus_name)
	AudioServer.set_bus_send(bus_index, &"Master")
	AudioServer.set_bus_volume_db(bus_index, bus_volume_db)
	var equalizer := _find_or_add_equalizer(bus_index)
	var gains: Array[float] = [hz_31, hz_62, hz_125, hz_250, hz_500, hz_1000, hz_2000, hz_4000, hz_8000, hz_16000]
	for band_index in gains.size():
		equalizer.set_band_gain_db(band_index, gains[band_index])

# 専用Bus上のEQ10を再利用し、存在しなければ追加する。
func _find_or_add_equalizer(bus_index: int) -> AudioEffectEQ10:
	for effect_index in AudioServer.get_bus_effect_count(bus_index):
		var effect := AudioServer.get_bus_effect(bus_index, effect_index)
		if effect is AudioEffectEQ10:
			return effect
	var equalizer := AudioEffectEQ10.new()
	AudioServer.add_bus_effect(bus_index, equalizer)
	return equalizer
