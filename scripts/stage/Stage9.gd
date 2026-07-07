# 2026-06-29: BoarにSMASH記憶を運ばせる記憶搬送路ステージ。
extends "res://scripts/stage/StageBase.gd"

var branch_lantern: Node # 分岐解放後に明るくするC地点の誘導灯。
var cracked_floor_group: Node # BoarがSMASH記憶を運んで壊す亀裂床。

# 共通初期化後、留め具破壊でBoar巡回路をCへ切り替える。
func _ready() -> void:
	super._ready()
	var latch := get_node_or_null("EditableGeometry/ActionBreakGroups/ActionBreakGroup_RouteLatch")
	var boar := get_node_or_null("BoarMonster")
	branch_lantern = get_node_or_null("GuidanceLantern_C")
	cracked_floor_group = get_node_or_null("EditableGeometry/ActionBreakGroups/ActionBreakGroup_CrackedFloorC")
	_set_branch_route_visible(false)
	if latch != null and boar != null and boar.has_method("open_patrol_branch"):
		latch.broken.connect(func(_enemy: Node, _record: Resource):
			boar.open_patrol_branch()
			_set_branch_route_visible(true)
			shake_camera(8.0, 0.12)
		)

func _build_world() -> void:
	var background := ColorRect.new()
	background.color = Color(0.052, 0.06, 0.082)
	background.size = Vector2(4200, 1800)
	background.position = Vector2(-1300, -620)
	background.z_index = -20
	add_child(background)

# Cルートが解放されたかどうかを視覚的に切り替える。
func _set_branch_route_visible(open: bool) -> void:
	if branch_lantern != null:
		branch_lantern.modulate = Color(1.0, 1.0, 1.0, 1.0) if open else Color(0.45, 0.55, 0.70, 0.45)
	if cracked_floor_group != null:
		cracked_floor_group.modulate = Color(1.0, 0.92, 0.70, 1.0) if open else Color(0.62, 0.62, 0.70, 0.72)
