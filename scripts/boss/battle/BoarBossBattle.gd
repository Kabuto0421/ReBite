# 2026-06-22: 5撃のボス攻略順と失敗復旧を管理する遭遇ステートマシン。
class_name BoarBossBattle
extends "res://scripts/boss/battle/BossBattleBase.gd"

const ReplayDamageResolverScript := preload("res://scripts/boss/core/ReplayDamageResolver.gd")
const PHASE_IDS: Array[StringName] = [&"Intro", &"TeachSmash", &"TeachDash", &"RockRecovery", &"FinalCharge", &"Clear"]

var falling_trap: Node # SMASHを教える吊り落石。
var timed_trap: Node # DASHを教える時限落石。
var rock_a: Node # 左側の再利用岩。
var rock_b: Node # 右側の再利用岩。
var stopper: Node # 岩固定後にDASHで使う中盤ギミック。
var final_wall: Node # 5撃目だけ有効になる最終壁。
var damage_resolver: Node # 再演由来イベントだけを通す検証部品。

# Stage10内の構成要素を接続してIntroから開始する。
func setup(
	stage_node: Node,
	boss_node: Node,
	player_node: Node,
	falling_node: Node,
	timed_node: Node,
	rock_a_node: Node,
	rock_b_node: Node,
	stopper_node: Node,
	wall_node: Node
) -> void:
	falling_trap = falling_node
	timed_trap = timed_node
	rock_a = rock_a_node
	rock_b = rock_b_node
	stopper = stopper_node
	final_wall = wall_node
	setup_battle_core(stage_node, boss_node, player_node, PHASE_IDS)
	_build_damage_resolver()
	_connect_events()
	_reset_gimmicks()
	start_battle()

# StateMachineからフェーズ開始処理を受け取る。
func _on_battle_phase_entered(phase_id: StringName, _payload: Variant = null) -> void:
	match phase_id:
		&"Intro":
			boss.set_physics_process(false)
		&"TeachSmash":
			boss.set_physics_process(true)
			falling_trap.arm(boss)
		&"TeachDash":
			falling_trap.set_attention_active(false)
			timed_trap.arm(boss)
		&"RockRecovery":
			timed_trap.set_attention_active(false)
			falling_trap.handoff_rock_actor()
			timed_trap.handoff_rock_actor()
			rock_a.activate()
			rock_b.activate()
			stopper.activate()
		&"FinalCharge":
			rock_a.set_attention_active(false)
			rock_b.set_attention_active(false)
			stopper.reset_gimmick()
			final_wall.expose()

# イントロ退場後に最初のSMASH教材を開始する。
func finish_intro() -> void:
	if current_phase() == &"Intro":
		change_phase(&"TeachSmash")

# 初回罠の成功・失敗を受け、どちらでも次フェーズへ進める。
func _on_initial_trap_resolved(trap_id: StringName, hit: bool, rock_id: StringName, event: Dictionary) -> void:
	var rock := _rock_by_id(rock_id)
	if hit:
		var damage_accepted: bool = damage_resolver.request_damage(event)
		if damage_accepted and rock != null:
			rock.consume_initial_hit()
	if trap_id == &"falling_rock":
		change_phase(&"TeachDash")
	else:
		change_phase(&"RockRecovery")

# 岩を固定したストッパーへのDASHを有効ダメージへ変換する。
func _on_stopper_impact(event: Dictionary, rock: Node) -> void:
	var damage_accepted: bool = damage_resolver.request_damage(event)
	if not damage_accepted:
		return
	rock.consume_use()
	if boss.current_hp <= 1:
		change_phase(&"FinalCharge")
	else:
		stopper.activate()
		_refresh_rock_attention()

# 最終壁への再演DASHを5撃目へ変換する。
func _on_final_wall_impact(event: Dictionary) -> void:
	damage_resolver.request_damage(event)

# 検証済みダメージだけをBossへ適用する。
func _on_damage_approved(event: Dictionary) -> void:
	boss.apply_environment_damage(event)

# 残り1HPでBoar固有の最終壁フェーズを解禁する。
func _on_boss_progress_changed(current_hp: int, _max_hp: int) -> void:
	if current_hp == 1 and current_phase() == &"RockRecovery":
		change_phase(&"FinalCharge")

# 再演イベント検証部品を生成する。
func _build_damage_resolver() -> void:
	damage_resolver = ReplayDamageResolverScript.new()
	damage_resolver.name = "ReplayDamageResolver"
	add_child(damage_resolver)
	damage_resolver.damage_approved.connect(_on_damage_approved)

# 各ギミックとBoss/Playerの通知を接続する。
func _connect_events() -> void:
	falling_trap.trap_resolved.connect(_on_initial_trap_resolved)
	timed_trap.trap_resolved.connect(_on_initial_trap_resolved)
	rock_a.socketed.connect(stopper.lock_with_rock)
	rock_b.socketed.connect(stopper.lock_with_rock)
	stopper.rock_locked.connect(_on_rock_locked)
	stopper.impact.connect(_on_stopper_impact)
	final_wall.final_impact.connect(_on_final_wall_impact)

# 全ギミックを初期配置へ戻す。
func _reset_gimmicks() -> void:
	if damage_resolver != null:
		damage_resolver.reset()
	falling_trap.reset_gimmick()
	timed_trap.reset_gimmick()
	rock_a.reset_gimmick()
	rock_b.reset_gimmick()
	stopper.reset_gimmick()
	final_wall.reset_gimmick()

# 一つの岩が固定されたら、次の操作対象をStopperだけに絞る。
func _on_rock_locked(_rock: Node) -> void:
	rock_a.set_attention_active(false)
	rock_b.set_attention_active(false)

# Stopper使用後、残っている岩だけを再び候補として示す。
func _refresh_rock_attention() -> void:
	rock_a.set_attention_active(rock_a.active and not rock_a.socketed_state)
	rock_b.set_attention_active(rock_b.active and not rock_b.socketed_state)

# IDから対応する再利用岩を返す。
func _rock_by_id(rock_id: StringName) -> Node:
	return rock_a if rock_a.rock_id == rock_id else (rock_b if rock_b.rock_id == rock_id else null)
