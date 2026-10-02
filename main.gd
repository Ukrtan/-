extends Node3D

var player: CharacterBody3D
var first_camera: Camera3D
var third_camera: Camera3D
var third_arm: SpringArm3D
var character_model: Node3D
var anim_player: AnimationPlayer
var swing_source: Node3D

var third_person := false
var crouching := false
var speed := 3.5
var crouch_speed := 1.8
var mouse_sensitivity := 0.0025
var pitch := 0.0
var yaw := 0.0
var action_playing := false
var has_character_mesh := false
var mannequin: Node3D

const ROOM_SIZE := 14.0
const STAND_HEIGHT := 1.6
const CROUCH_HEIGHT := 1.05
const STAND_COLLISION_HEIGHT := 1.8
const CROUCH_COLLISION_HEIGHT := 1.25

func _ready() -> void:
    _setup_world()
    _load_room()
    _make_player()
    _load_character_and_animations()
    _update_camera_mode()
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _setup_world() -> void:
    var environment := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.08, 0.08, 0.1)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.7, 0.72, 0.8)
    env.ambient_light_energy = 0.8
    environment.environment = env
    add_child(environment)

    var light := DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-55.0, -25.0, 0.0)
    light.light_energy = 1.1
    light.shadow_enabled = true
    add_child(light)

func _load_room() -> void:
    var room_path := "res://комната для игры.glb"
    if ResourceLoader.exists(room_path):
        var scene = load(room_path)
        if scene:
            var room = scene.instantiate()
            room.name = "Room"
            add_child(room)
            _make_collision_from_meshes(room)
    _make_safety_boundaries()

func _make_collision_from_meshes(root: Node) -> void:
    # Add StaticBody3D collision to visible mesh objects that have no collision.
    _add_mesh_collisions_recursive(root)

func _add_mesh_collisions_recursive(node: Node) -> void:
    for child in node.get_children():
        if child is MeshInstance3D:
            var mesh_instance := child as MeshInstance3D
            if mesh_instance.mesh and mesh_instance.get_parent() is not StaticBody3D:
                var static_body := StaticBody3D.new()
                static_body.name = mesh_instance.name + "_Collision"
                var parent := mesh_instance.get_parent()
                parent.add_child(static_body)
                var collision := CollisionShape3D.new()
                var shape := mesh_instance.mesh.create_trimesh_shape()
                if shape:
                    collision.shape = shape
                    static_body.global_transform = mesh_instance.global_transform
                    static_body.add_child(collision)
        _add_mesh_collisions_recursive(child)

func _make_safety_boundaries() -> void:
    var floor := StaticBody3D.new()
    floor.name = "SafetyFloor"
    add_child(floor)

    var floor_shape := CollisionShape3D.new()
    var floor_box := BoxShape3D.new()
    floor_box.size = Vector3(ROOM_SIZE, 0.2, ROOM_SIZE)
    floor_shape.shape = floor_box
    floor_shape.position.y = -0.1
    floor.add_child(floor_shape)

    var walls := [
        [Vector3(0, 2.0, -ROOM_SIZE / 2.0), Vector3(ROOM_SIZE, 4.0, 0.2)],
        [Vector3(0, 2.0, ROOM_SIZE / 2.0), Vector3(ROOM_SIZE, 4.0, 0.2)],
        [Vector3(-ROOM_SIZE / 2.0, 2.0, 0), Vector3(0.2, 4.0, ROOM_SIZE)],
        [Vector3(ROOM_SIZE / 2.0, 2.0, 0), Vector3(0.2, 4.0, ROOM_SIZE)]
    ]

    for data in walls:
        var wall := StaticBody3D.new()
        add_child(wall)
        var shape := CollisionShape3D.new()
        var box := BoxShape3D.new()
        box.size = data[1]
        shape.shape = box
        shape.position = data[0]
        wall.add_child(shape)

func _make_player() -> void:
    player = CharacterBody3D.new()
    player.name = "Player"
    player.position = Vector3(0, 0.05, 0)
    add_child(player)

    var collision := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.height = STAND_COLLISION_HEIGHT
    capsule.radius = 0.35
    collision.shape = capsule
    collision.position.y = STAND_COLLISION_HEIGHT / 2.0
    collision.name = "PlayerCollision"
    player.add_child(collision)

    first_camera = Camera3D.new()
    first_camera.name = "FirstPersonCamera"
    first_camera.position = Vector3(0, STAND_HEIGHT, 0)
    first_camera.fov = 75.0
    player.add_child(first_camera)

    third_arm = SpringArm3D.new()
    third_arm.name = "ThirdPersonArm"
    third_arm.position = Vector3(0, 1.2, 0)
    third_arm.spring_length = 4.0
    third_arm.margin = 0.15
    player.add_child(third_arm)

    third_camera = Camera3D.new()
    third_camera.name = "ThirdPersonCamera"
    third_camera.fov = 70.0
    third_arm.add_child(third_camera)

func _load_character_and_animations() -> void:
    var jogging_path := "res://Jogging.fbx"
    if ResourceLoader.exists(jogging_path):
        var scene = load(jogging_path)
        if scene:
            character_model = scene.instantiate()
            character_model.name = "Character"
            player.add_child(character_model)
            anim_player = _find_animation_player(character_model)

            # The FBX can contain an animation skeleton without a visible mesh.
            # Keep all visual MeshInstance3D nodes visible in third person.
            _prepare_character_visual(character_model)
            has_character_mesh = _contains_mesh(character_model)
            if not has_character_mesh:
                _make_visible_mannequin()

    var swing_path := "res://Kettlebell Swing.fbx"
    if ResourceLoader.exists(swing_path):
        var swing_scene = load(swing_path)
        if swing_scene:
            swing_source = swing_scene.instantiate()
            swing_source.name = "KettlebellSwingSource"
            swing_source.visible = false
            player.add_child(swing_source)

            var source_player := _find_animation_player(swing_source)
            if anim_player and source_player:
                _copy_animation_library(source_player, anim_player)

    if character_model == null and swing_source != null:
        character_model = swing_source
        character_model.visible = third_person
        anim_player = _find_animation_player(character_model)
        _prepare_character_visual(character_model)
        has_character_mesh = _contains_mesh(character_model)
        if not has_character_mesh:
            _make_visible_mannequin()

    if mannequin:
        mannequin.visible = third_person

func _contains_mesh(root: Node) -> bool:
    if root is MeshInstance3D:
        return true
    for child in root.get_children():
        if _contains_mesh(child):
            return true
    return false

func _make_visible_mannequin() -> void:
    if mannequin != null:
        return
    mannequin = Node3D.new()
    mannequin.name = "VisibleCharacterFallback"
    player.add_child(mannequin)

    var body := MeshInstance3D.new()
    var body_mesh := CapsuleMesh.new()
    body_mesh.height = 1.0
    body_mesh.radius = 0.32
    body.mesh = body_mesh
    body.position.y = 1.0
    mannequin.add_child(body)

    var head := MeshInstance3D.new()
    var head_mesh := SphereMesh.new()
    head_mesh.radius = 0.25
    head_mesh.height = 0.5
    head.mesh = head_mesh
    head.position.y = 1.75
    mannequin.add_child(head)

    var left_arm := _make_limb(Vector3(-0.48, 1.05, 0), 0.8)
    var right_arm := _make_limb(Vector3(0.48, 1.05, 0), 0.8)
    var left_leg := _make_limb(Vector3(-0.18, 0.35, 0), 0.9)
    var right_leg := _make_limb(Vector3(0.18, 0.35, 0), 0.9)
    mannequin.add_child(left_arm)
    mannequin.add_child(right_arm)
    mannequin.add_child(left_leg)
    mannequin.add_child(right_leg)

func _make_limb(pos: Vector3, height: float) -> MeshInstance3D:
    var limb := MeshInstance3D.new()
    var mesh := CapsuleMesh.new()
    mesh.height = height
    mesh.radius = 0.12
    limb.mesh = mesh
    limb.position = pos
    return limb

func _prepare_character_visual(root: Node) -> void:
    for node in root.get_children():
        _prepare_character_visual(node)
    if root is MeshInstance3D:
        root.visible = true
        var mesh_node := root as MeshInstance3D
        if mesh_node.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
            mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

func _find_animation_player(node: Node) -> AnimationPlayer:
    if node is AnimationPlayer:
        return node
    for child in node.get_children():
        var found := _find_animation_player(child)
        if found:
            return found
    return null

func _copy_animation_library(source: AnimationPlayer, target: AnimationPlayer) -> void:
    var library_out := AnimationLibrary.new()
    for library_name in source.get_animation_library_list():
        var library := source.get_animation_library(library_name)
        if library == null:
            continue
        for animation_name in library.get_animation_list():
            var animation := library.get_animation(animation_name)
            if animation:
                library_out.add_animation(animation_name, animation.duplicate())
    if library_out.get_animation_list().size() > 0:
        if target.has_animation_library("actions"):
            target.remove_animation_library("actions")
        target.add_animation_library("actions", library_out)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed:
        Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        yaw -= event.relative.x * mouse_sensitivity
        pitch = clamp(pitch - event.relative.y * mouse_sensitivity, -1.35, 1.35)
        player.rotation.y = yaw
        first_camera.rotation.x = pitch
        third_arm.rotation.x = pitch

    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_ESCAPE:
            Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
        elif event.keycode == KEY_V:
            third_person = not third_person
            _update_camera_mode()
        elif event.keycode == KEY_C:
            _play_kettlebell()
        elif event.keycode == KEY_CTRL:
            _set_crouch(not crouching)

func _update_camera_mode() -> void:
    first_camera.current = not third_person
    third_camera.current = third_person
    if character_model:
        character_model.visible = third_person

func _set_crouch(value: bool) -> void:
    crouching = value
    var collision := player.get_node("PlayerCollision") as CollisionShape3D
    var capsule := collision.shape as CapsuleShape3D

    if crouching:
        capsule.height = CROUCH_COLLISION_HEIGHT
        collision.position.y = CROUCH_COLLISION_HEIGHT / 2.0
        first_camera.position.y = CROUCH_HEIGHT
        third_arm.position.y = 0.95
    else:
        capsule.height = STAND_COLLISION_HEIGHT
        collision.position.y = STAND_COLLISION_HEIGHT / 2.0
        first_camera.position.y = STAND_HEIGHT
        third_arm.position.y = 1.2

func _physics_process(delta: float) -> void:
    if player == null:
        return

    # Hold Ctrl to crouch. The camera and collision follow the crouched height.
    var wants_crouch := Input.is_key_pressed(KEY_CTRL)
    if wants_crouch != crouching:
        _set_crouch(wants_crouch)

    var x := float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
    var z := float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
    var input_vec := Vector2(x, z)
    var moving := input_vec.length() > 0.01

    if moving:
        input_vec = input_vec.normalized()
        var direction := (player.transform.basis * Vector3(input_vec.x, 0, input_vec.y)).normalized()
        var current_speed := crouch_speed if crouching else speed
        player.velocity.x = direction.x * current_speed
        player.velocity.z = direction.z * current_speed
    else:
        player.velocity.x = move_toward(player.velocity.x, 0.0, speed * 8.0 * delta)
        player.velocity.z = move_toward(player.velocity.z, 0.0, speed * 8.0 * delta)

    if not player.is_on_floor():
        player.velocity.y -= 12.0 * delta
    else:
        player.velocity.y = 0.0

    player.move_and_slide()

    if anim_player and not action_playing and moving:
        _play_animation_containing(["jog", "walk", "run"])

func _play_animation_containing(words: Array[String]) -> void:
    if anim_player == null:
        return
    for name in anim_player.get_animation_list():
        var lower := name.to_lower()
        for word in words:
            if word in lower:
                if anim_player.current_animation != name:
                    anim_player.play(name)
                return

func _play_kettlebell() -> void:
    if anim_player == null:
        return

    for name in anim_player.get_animation_list():
        var lower := name.to_lower()
        if "kettlebell" in lower or "swing" in lower:
            action_playing = true
            anim_player.play(name)
            await anim_player.animation_finished
            action_playing = false
            return

    var names := anim_player.get_animation_list()
    if names.size() > 0:
        action_playing = true
        anim_player.play(names[0])
        await anim_player.animation_finished
        action_playing = false
