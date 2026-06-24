# 2026-06-22: ボス戦共通のフェーズ管理、進捗通知、撃破完了を提供する基底クラス。
class_name BossBattleBase
extends Node

signal phase_changed(phase_id: StringName) # 現在の攻略フェーズを通知する。
signal progress_changed(damage: int, max_damage: int) # HUD用のボスダメージ進捗。
signal battle_cleared # ボス戦の完了を通知する。

const StateMachineScript := preload("res://scripts/core/StateMachine.gd")
const PhaseStateScript := preload("res://scripts/boss/battle/BossBattlePhaseState.gd")

var stage: Node # ボス戦を所有するStage。
var boss: Node # 攻略対象のBoss。
var player: Node # ボス戦へ参加するPlayer。
var state_machine: Node # ボス戦専用状態機械。
var initial_phase_id: StringName # 開始フェーズID。
var clear_phase_id: StringName # 完了フェーズID。

# 共通参照とフェーズ一覧を登録し、状態機械を構築する。
func setup_battle_core(
	stage_node: Node,
	boss_node: Node,
	player_node: Node,
	phase_ids: Array[StringName],
	start_phase: StringName = &"Intro",
	completed_phase: StringName = &"Clear"
) -> void:
	stage = stage_node
	boss = boss_node
	player = player_node
	initial_phase_id = start_phase
	clear_phase_id = completed_phase
	_build_state_machine(phase_ids)
	_connect_common_events()

# 固有ギミックの準備完了後、登録済み開始フェーズへ入る。
func start_battle() -> void:
	state_machine.initialize(self, initial_phase_id)

# 状態ノードからの開始通知を共通信号と派生処理へ分配する。
func on_phase_entered(phase_id: StringName, payload: Variant = null) -> void:
	phase_changed.emit(phase_id)
	_on_battle_phase_entered(phase_id, payload)
	if phase_id == clear_phase_id:
		battle_cleared.emit()

# 現在のボス戦フェーズ名を返す。
func current_phase() -> StringName:
	return state_machine.current_state.name if state_machine != null and state_machine.current_state != null else &""

# 登録済みフェーズへ遷移する。
func change_phase(phase_id: StringName, payload: Variant = null) -> void:
	if state_machine != null:
		state_machine.change_state(phase_id, payload)

# 派生ボス戦がフェーズ固有処理を実装するためのフック。
func _on_battle_phase_entered(_phase_id: StringName, _payload: Variant = null) -> void:
	pass

# 派生ボス戦がHP条件による追加遷移を実装するためのフック。
func _on_boss_progress_changed(_current_hp: int, _max_hp: int) -> void:
	pass

# フェーズIDに対応する状態ノードを生成する。
func _build_state_machine(phase_ids: Array[StringName]) -> void:
	state_machine = StateMachineScript.new()
	state_machine.name = "BossBattleStateMachine"
	add_child(state_machine)
	for phase_id in phase_ids:
		var phase := PhaseStateScript.new()
		phase.name = str(phase_id)
		phase.phase_id = phase_id
		state_machine.add_child(phase)

# Bossの共通HP通知と撃破通知を接続する。
func _connect_common_events() -> void:
	if not boss.boss_hp_changed.is_connected(_on_boss_hp_changed):
		boss.boss_hp_changed.connect(_on_boss_hp_changed)
	if not boss.boss_defeated.is_connected(_on_boss_defeated):
		boss.boss_defeated.connect(_on_boss_defeated)

# Boss HPを累積ダメージへ変換して通知する。
func _on_boss_hp_changed(current_hp: int, max_hp: int) -> void:
	progress_changed.emit(max_hp - current_hp, max_hp)
	_on_boss_progress_changed(current_hp, max_hp)

# Boss撃破時に完了フェーズへ遷移する。
func _on_boss_defeated() -> void:
	change_phase(clear_phase_id)
