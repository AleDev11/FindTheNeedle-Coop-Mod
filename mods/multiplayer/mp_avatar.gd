# Remote player puppet: a simple figure built from primitives, a name tag and
# the tool they are holding. Poses arrive ~20 times a second and are smoothed.
extends Node3D

const TOOL_NAMES := ["mano", "pala", "horca", "escoba", "palita", "detector", "aspiradora", "mechero", "construir"]
const TOOL_MODELS := {
	1: "res://assets/downloaded/models/rusted_spade_01/rusted_spade_01_1k.gltf",
	2: "res://assets/models/pitchfork.glb",
	3: "res://assets/models/broom.glb",
	4: "res://assets/models/sand_shovel.glb",
	5: "res://assets/models/metal_detector.glb",
	6: "res://assets/models/yard_vac.glb",
}
const TOOL_LENGTH := 1.2
const EYE := 1.66

var _target_pos := Vector3.ZERO
var _target_yaw := 0.0
var _target_pitch := 0.0
var _crouch := 0.0
var _moving := 0.0
var _tool := -1
var _has_target := false
var _walk := 0.0

var _body: Node3D
var _head: Node3D
var _hand: Node3D
var _tool_node: Node3D
var _label: Label3D
var _name := ""
var _color := Color.WHITE
static var _model_cache := {}


func setup(pname: String, color: Color) -> void:
	_name = pname
	_color = color


func _ready() -> void:
	var skin := StandardMaterial3D.new()
	skin.albedo_color = _color
	skin.roughness = 0.8
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.08, 0.09, 0.11)
	dark.roughness = 0.35
	dark.metallic = 0.4
	var boots := StandardMaterial3D.new()
	boots.albedo_color = _color.darkened(0.55)

	_body = Node3D.new()
	add_child(_body)
	var torso := _mesh(CapsuleMesh.new(), skin)
	(torso.mesh as CapsuleMesh).radius = 0.27
	(torso.mesh as CapsuleMesh).height = 0.95
	torso.position.y = 1.05
	_body.add_child(torso)
	for side in [-1.0, 1.0]:
		var leg := _mesh(CapsuleMesh.new(), boots)
		(leg.mesh as CapsuleMesh).radius = 0.11
		(leg.mesh as CapsuleMesh).height = 0.72
		leg.position = Vector3(0.12 * side, 0.36, 0.0)
		leg.name = "LegL" if side < 0 else "LegR"
		_body.add_child(leg)

	_head = Node3D.new()
	_head.position.y = EYE - 0.08
	_body.add_child(_head)
	var skull := _mesh(SphereMesh.new(), skin)
	(skull.mesh as SphereMesh).radius = 0.2
	(skull.mesh as SphereMesh).height = 0.4
	_head.add_child(skull)
	var visor := _mesh(BoxMesh.new(), dark)
	(visor.mesh as BoxMesh).size = Vector3(0.3, 0.1, 0.12)
	visor.position = Vector3(0, 0.03, -0.15)
	_head.add_child(visor)

	# left arm hangs by the side
	var left_arm := _mesh(CapsuleMesh.new(), skin)
	(left_arm.mesh as CapsuleMesh).radius = 0.085
	(left_arm.mesh as CapsuleMesh).height = 0.62
	left_arm.position = Vector3(-0.33, 1.05, 0.0)
	left_arm.rotation.z = 0.12
	_body.add_child(left_arm)

	# the right arm pivots with the look pitch, so the tool points where they aim
	_hand = Node3D.new()
	_hand.position = Vector3(0.33, 1.35, 0.0)
	_body.add_child(_hand)
	var right_arm := _mesh(CapsuleMesh.new(), skin)
	(right_arm.mesh as CapsuleMesh).radius = 0.085
	(right_arm.mesh as CapsuleMesh).height = 0.62
	right_arm.position = Vector3(0.0, 0.0, -0.26)
	right_arm.rotation.x = PI / 2.0
	_hand.add_child(right_arm)
	var fist := _mesh(SphereMesh.new(), skin)
	(fist.mesh as SphereMesh).radius = 0.085
	(fist.mesh as SphereMesh).height = 0.17
	fist.position = Vector3(0.0, 0.0, -0.52)
	_hand.add_child(fist)

	_label = Label3D.new()
	_label.text = _name
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.fixed_size = true
	_label.pixel_size = 0.0016
	_label.font_size = 22
	_label.outline_size = 8
	_label.modulate = _color.lightened(0.35)
	_label.position.y = EYE + 0.55
	add_child(_label)


func _mesh(m: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return mi


func set_target(pos: Vector3, yaw: float, pitch: float, tool: int, crouch: float, moving: float) -> void:
	_target_pos = pos
	_target_yaw = yaw
	_target_pitch = pitch
	_crouch = crouch
	_moving = moving
	if not _has_target:
		_has_target = true
		global_position = pos
		rotation.y = yaw
	if tool != _tool:
		_tool = tool
		_set_tool_model(tool)


func _process(delta: float) -> void:
	if not _has_target:
		return
	var k := 1.0 - exp(-14.0 * delta)
	if global_position.distance_to(_target_pos) > 6.0:
		global_position = _target_pos
	else:
		global_position = global_position.lerp(_target_pos, k)
	rotation.y = lerp_angle(rotation.y, _target_yaw, k)
	_head.rotation.x = lerpf(_head.rotation.x, _target_pitch, k)
	_hand.rotation.x = lerpf(_hand.rotation.x, _target_pitch * 0.8 - 0.35, k)
	_body.scale.y = lerpf(_body.scale.y, 1.0 - 0.3 * _crouch, k)
	# a little walk cycle
	if _moving > 0.3:
		_walk += delta * clampf(_moving, 1.0, 9.0) * 1.6
	else:
		_walk = lerpf(_walk, round(_walk / PI) * PI, k)
	var swing := sin(_walk) * 0.5 * clampf(_moving / 4.0, 0.0, 1.0)
	var l := _body.get_node_or_null("LegL")
	var r := _body.get_node_or_null("LegR")
	if l != null:
		l.rotation.x = swing
	if r != null:
		r.rotation.x = -swing
	var tool_txt: String = TOOL_NAMES[_tool] if _tool >= 0 and _tool < TOOL_NAMES.size() else ""
	_label.text = _name if tool_txt == "" or _tool == 0 else "%s\n[%s]" % [_name, tool_txt]


func _set_tool_model(tool: int) -> void:
	if _tool_node != null:
		_tool_node.queue_free()
		_tool_node = null
	var path: String = TOOL_MODELS.get(tool, "")
	if path == "" or not ResourceLoader.exists(path):
		return
	var scene: PackedScene = _model_cache.get(path)
	if scene == null:
		scene = load(path) as PackedScene
		if scene == null:
			return
		_model_cache[path] = scene
	var inst := scene.instantiate() as Node3D
	if inst == null:
		return
	# normalise every tool to about the same length, pointing forward
	var holder := Node3D.new()
	holder.add_child(inst)
	var box := _aabb(inst, Transform3D.IDENTITY)
	var longest := maxf(box.size.x, maxf(box.size.y, box.size.z))
	if longest > 0.001:
		var s := TOOL_LENGTH / longest
		inst.scale = Vector3.ONE * s
		inst.position = -box.get_center() * s
		if box.size.y >= box.size.x and box.size.y >= box.size.z:
			holder.rotation.x = -PI / 2.0  # long axis up -> forward
		elif box.size.x >= box.size.z:
			holder.rotation.y = PI / 2.0
	# hold it just past the fist, angled down a little like a carried tool
	holder.position = Vector3(0.0, -0.05, -0.52 - TOOL_LENGTH * 0.35)
	holder.rotation.x += 0.25
	_hand.add_child(holder)
	_tool_node = holder


func _aabb(n: Node, xf: Transform3D) -> AABB:
	var out := AABB()
	var first := true
	var here := xf
	if n is Node3D:
		here = xf * (n as Node3D).transform
	if n is VisualInstance3D:
		var b := here * (n as VisualInstance3D).get_aabb()
		out = b
		first = false
	for c in n.get_children():
		var cb := _aabb(c, here)
		if cb.size != Vector3.ZERO:
			if first:
				out = cb
				first = false
			else:
				out = out.merge(cb)
	return out
