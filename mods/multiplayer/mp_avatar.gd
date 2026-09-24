# Remote player puppet: an animated farmer (models/farmer.glb), a name tag and
# the tool they are holding. If the model is missing or fails to load, a simple
# figure built from primitives stands in. Poses arrive ~20 times a second and
# are smoothed.
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

# The farmer: "Ultimate Modular Men Pack" by Quaternius (CC0), trimmed to the
# clips used here by dev/models/slim_glb.py. Loaded at runtime with
# GLTFDocument, so it lives beside the scripts and never touches the game pack.
const MODEL_FILE := "models/farmer.glb"
const MODEL_HEIGHT := 1.8  # hat included
const WALK_SPEED := 3.0  # ground speed (m/s) the Walk clip matches at speed 1
const RUN_SPEED := 5.5  # faster than this plays Run
const RUN_CLIP_SPEED := 6.5  # ground speed the Run clip matches at speed 1
const TINTS := {"LightBlue": 0.25, "Red": 0.0}  # material -> how much to darken the player colour

var _target_pos := Vector3.ZERO
var _target_yaw := 0.0
var _target_pitch := 0.0
var _crouch := 0.0
var _moving := 0.0
var _tool := -1
var flip_tool := false  # turn the held tool 180 degrees (for new models)
var _has_target := false
var _walk := 0.0
var _pitch := 0.0

var _body: Node3D
var _head: Node3D
var _hand: Node3D
var _tool_node: Node3D
var _label: Label3D
var _name := ""
var _color := Color.WHITE
static var _model_cache := {}

# farmer model (null when running on the primitive fallback)
var _skel: Skeleton3D
var _anim: AnimationPlayer
var _clip := ""
var _b_head := -1
var _b_upper := -1
var _b_lower := -1
var _b_wrist := -1
var _b_palm := -1
static var _farmer: PackedScene
static var _farmer_tried := false


func setup(pname: String, color: Color) -> void:
	_name = pname
	_color = color


func _ready() -> void:
	_body = Node3D.new()
	add_child(_body)
	if not _build_farmer():
		_build_figure()

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


# ---------------------------------------------------------------- farmer model

static func _load_farmer(dir: String) -> PackedScene:
	if _farmer_tried:
		return _farmer
	_farmer_tried = true
	var path := dir.path_join(MODEL_FILE)
	if not FileAccess.file_exists(path):
		push_warning("[MPMod] %s not found, using the simple avatar" % path)
		return null
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file(path, state)
	var root: Node = doc.generate_scene(state) if err == OK else null
	if root == null:
		push_warning("[MPMod] could not load %s (error %d), using the simple avatar" % [path, err])
		return null
	var scene := PackedScene.new()
	if scene.pack(root) == OK:
		_farmer = scene
	root.free()
	return _farmer


func _build_farmer() -> bool:
	var scene := _load_farmer(get_script().resource_path.get_base_dir())
	if scene == null:
		return false
	var model := scene.instantiate() as Node3D
	if model == null:
		return false
	var skels := model.find_children("*", "Skeleton3D", true, false)
	var anims := model.find_children("*", "AnimationPlayer", true, false)
	if skels.is_empty() or anims.is_empty():
		model.free()
		return false
	_skel = skels[0]
	_anim = anims[0]
	_b_head = _skel.find_bone("Head")
	_b_upper = _skel.find_bone("UpperArm.R")
	_b_lower = _skel.find_bone("LowerArm.R")
	_b_wrist = _skel.find_bone("Wrist.R")
	_b_palm = _skel.find_bone("Middle1.R")

	# stand it on the ground at a fixed height, facing -Z like the player
	var box := _aabb(model, Transform3D.IDENTITY)
	var s := MODEL_HEIGHT / maxf(box.size.y, 0.001)
	var holder := Node3D.new()
	holder.rotation.y = PI
	holder.scale = Vector3.ONE * s
	holder.position.y = -box.position.y * s
	holder.add_child(model)
	_body.add_child(holder)

	# dye the overalls and the hat band in the player's colour
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(i) as BaseMaterial3D
			if mat != null and TINTS.has(mat.resource_name):
				var dyed := mat.duplicate() as BaseMaterial3D
				dyed.albedo_color = _color.darkened(TINTS[mat.resource_name])
				mi.set_surface_override_material(i, dyed)

	for clip in ["Idle", "Walk", "Run"]:
		if _anim.has_animation(clip):
			_anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	# advanced by hand in _process, so the head and arm can be posed on top
	_anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_play("Idle", 0.0)

	# tools hang from a grip that follows the right hand every frame
	_hand = Node3D.new()
	add_child(_hand)
	return true


func _play(clip: String, blend: float) -> void:
	if clip == _clip or not _anim.has_animation(clip):
		return
	_clip = clip
	_anim.play(clip, blend)


func _animate_farmer(delta: float) -> void:
	var clip := "Idle"
	if _moving > RUN_SPEED:
		clip = "Run"
	elif _moving > 0.3:
		clip = "Walk"
	_play(clip, 0.2)
	match clip:
		"Walk":
			_anim.speed_scale = clampf(_moving / WALK_SPEED, 0.5, 1.6)
		"Run":
			_anim.speed_scale = clampf(_moving / RUN_CLIP_SPEED, 0.8, 1.6)
		_:
			_anim.speed_scale = 1.0
	# bones the clips may not key would keep last frame's pose: start clean
	for b in [_b_head, _b_upper, _b_lower]:
		if b >= 0:
			_skel.reset_bone_pose(b)
	_anim.advance(delta)

	var right := global_basis.x.normalized()
	var fwd := -global_basis.z.normalized()
	if _b_head >= 0:
		_turn_bone(_b_head, right, clampf(_pitch, -0.7, 0.7))
	var holding := _tool_node != null
	if holding and _b_upper >= 0 and _b_lower >= 0 and _b_wrist >= 0:
		# upper arm down along the side, forearm out front following the aim
		_aim_bone(_b_upper, _b_lower, fwd.rotated(right, -1.05 + _pitch * 0.25))
		_aim_bone(_b_lower, _b_wrist, fwd.rotated(right, -0.3 + _pitch * 0.8))
	var grip_bone := _b_palm if _b_palm >= 0 else _b_wrist
	if grip_bone >= 0:
		var grip := _skel.global_transform * _skel.get_bone_global_pose(grip_bone)
		_hand.global_transform = Transform3D(
			Basis(right, _pitch * 0.8 - 0.35) * global_basis.orthonormalized(), grip.origin)


# Rotate a bone by `angle` around a world-space axis, on top of its current pose.
func _turn_bone(b: int, axis_world: Vector3, angle: float) -> void:
	var axis := (_skel.global_basis.inverse() * axis_world).normalized()
	_rotate_bone(b, Quaternion(axis, angle))


# Swing a bone so it points from its head towards its child along `dir_world`.
func _aim_bone(b: int, child: int, dir_world: Vector3) -> void:
	var from := _skel.get_bone_global_pose(b).origin
	var to := _skel.get_bone_global_pose(child).origin
	var cur := (to - from).normalized()
	var want := (_skel.global_basis.inverse() * dir_world).normalized()
	if cur.is_zero_approx() or want.is_zero_approx() or cur.dot(want) > 0.9999:
		return
	_rotate_bone(b, Quaternion(cur, want))


# Apply a skeleton-space rotation to a bone, keeping it in its parent's frame.
func _rotate_bone(b: int, rot: Quaternion) -> void:
	var parent := _skel.get_bone_parent(b)
	var pg := Quaternion.IDENTITY
	if parent >= 0:
		pg = _skel.get_bone_global_pose(parent).basis.get_rotation_quaternion()
	var g := _skel.get_bone_global_pose(b).basis.get_rotation_quaternion()
	_skel.set_bone_pose_rotation(b, (pg.inverse() * rot * g).normalized())


# ---------------------------------------------------------------- simple figure

func _build_figure() -> void:
	var skin := StandardMaterial3D.new()
	skin.albedo_color = _color
	skin.roughness = 0.8
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.08, 0.09, 0.11)
	dark.roughness = 0.35
	dark.metallic = 0.4
	var boots := StandardMaterial3D.new()
	boots.albedo_color = _color.darkened(0.55)

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


func _animate_figure(delta: float, k: float) -> void:
	_head.rotation.x = _pitch
	_hand.rotation.x = lerpf(_hand.rotation.x, _target_pitch * 0.8 - 0.35, k)
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


func _mesh(m: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return mi


# ---------------------------------------------------------------- pose

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
		_pitch = pitch
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
	_pitch = lerpf(_pitch, _target_pitch, k)
	_body.scale.y = lerpf(_body.scale.y, 1.0 - 0.3 * _crouch, k)
	if _skel != null:
		_animate_farmer(delta)
	else:
		_animate_figure(delta, k)
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
		# Which way the tool points along its long axis. The default puts the
		# working end (blade, fork, nozzle) away from the hand; flip_tool turns
		# it 180 degrees, which is handy when trying out new tool models.
		var turn := -1.0 if flip_tool else 1.0
		if box.size.y >= box.size.x and box.size.y >= box.size.z:
			holder.rotation.x = turn * PI / 2.0  # long axis up -> forward
		elif box.size.x >= box.size.z:
			holder.rotation.y = -turn * PI / 2.0
	if _skel != null:
		# the grip is the palm itself: gripped a third of the way down the shaft
		holder.position = Vector3(0.0, 0.0, -TOOL_LENGTH * 0.2)
	else:
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
