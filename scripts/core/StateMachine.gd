# 2026-06-13: 状態の登録と遷移を管理する。
class_name StateMachine
extends Node

@export var initial_state_name: StringName # 初期状態名。

var states: Dictionary = {} # 名前から状態ノードを引く表。
var current_state: Node # 現在実行中の状態。

# 子状態を登録して初期状態へ入る。
func initialize(owner_node: Node, start_state: StringName = initial_state_name) -> void:
	states.clear()
	for child in get_children():
		if child.has_method("enter") and child.has_method("physics_update"):
			states[child.name] = child
			child.setup(owner_node)
			if not child.transition_requested.is_connected(_on_transition_requested):
				child.transition_requested.connect(_on_transition_requested)

	if start_state != &"":
		change_state(start_state)

# 現在状態を終了し、次の状態へ切り替える。
func change_state(next_state_name: StringName, payload: Variant = null) -> void:
	if not states.has(next_state_name):
		push_error("Unknown state: %s" % next_state_name)
		return

	if current_state != null:
		current_state.exit()

	current_state = states[next_state_name]
	current_state.enter(payload)

# 現在状態の物理更新を進める。
func physics_update(delta: float) -> void:
	if current_state != null:
		current_state.physics_update(delta)

# 現在状態の通常更新を進める。
func process_update(delta: float) -> void:
	if current_state != null:
		current_state.process_update(delta)

# 現在状態へ入力を渡す。
func handle_input(event: InputEvent) -> void:
	if current_state != null:
		current_state.handle_input(event)

# 状態からの遷移要求を受け取る。
func _on_transition_requested(next_state_name: StringName, payload: Variant = null) -> void:
	change_state(next_state_name, payload)
