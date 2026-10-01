extends Node3D

var player: CharacterBody3D
var first_camera: Camera3D
var third_camera: Camera3D
var third_arm: SpringArm3D
var character_model: Node3D
var anim_player: AnimationPlayer
var swing_source: Node3D

var third_person := false
var speed := 3.5
var mouse_sensitivity := 0.0025
var pitch := 0.0
var yaw := 0.0
var action_playing := false
var imported_room := false

const ROOM_SIZE := 14.0
const FLOOR_Y := 0.0

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
    env.ambient_light_color = Color(0.65, 0.68, 0.75)
    env.ambient_light_energy = 0.75
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
            imported_room = true

    # Safety collision around the imported room so the player cannot leave it.
    _make_collision_room()

func _make_collision_room() -> void:
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
        wall.name = "SafetyWall"
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
    capsule.height = 1.8
    capsule.radius = 0.35
    collision.shape = capsule
    collision.position.y = 0.9
    player.add_child(collision)

    first_camera = Camera3D.new()
    first_camera.name = "FirstPersonCamera"
    first_camera.position = Vector3(0, 1.6, 0)
    first_camera.fov = 75.0
    player.add_child(first_camera)

    third_arm = SpringArm3D.new()
    third_arm.name = "ThirdPersonArm"
    third_arm.position = Vector3(0, 1.25, 0)
    third_arm.spring_length = 4.0
    third_arm.margin = 0.15
    player.add_child(third_arm)

    third_camera = Camera3D.new()
    third_camera.name = "ThirdPersonCamera"
    third_camera.fov = 70.0
    third_arm.add_child(third_camera)

func _load_character_and_animations() -> void:
    # Jogging.fbx is the visible character/animation source when available.
    var jogging_path := "res://Jogging.fbx"
    if ResourceLoader.exists(jogging_path):
        var scene = load(jogging_path)
        if scene:
            character_model = scene.instantiate()
            character_model.name = "Character"
            player.add_child(character_model)
            anim_player = _find_animation_player(character_model)

    # Kettlebell Swing is loaded as a second animation source.
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

    # If Jogging is unavailable, show the kettlebell FBX as a fallback character.
    if character_model == null and swing_source != null:
        character_model = swing_source
        character_model.visible = third_person
        anim_player = _find_animation_player(character_model)

func _find_animation_player(node: Node) -> AnimationPlayer:
    if node is AnimationPlayer:
        return node

    for child in node.get_children():
        var found := _find_animation_player(child)
        if found:
            return found

    return null

func _copy_animation_library(source: AnimationPlayer, target: AnimationPlayer) -> void:
    var target_library := AnimationLibrary.new()

    for library_name in source.get_animation_library_list():
        var library := source.get_animation_library(library_name)
        if library == null:
            continue

        for animation_name in library.get_animation_list():
            var animation := library.get_animation(animation_name)
            if animation:
                target_library.add_animation(animation_name, animation.duplicate())

    if target_library.get_animation_list().size() > 0:
        if target.has_animation_library("actions"):
            target.remove_animation_library("actions")
        target.add_animation_library("actions", target_library)

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

func _update_camera_mode() -> void:
    if not first_camera or not third_camera:
        return

    first_camera.current = not third_person
    third_camera.current = third_person

    if character_model:
        character_model.visible = third_person

func _physics_process(delta: float) -> void:
    if player == null:
        return

    var x := float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
    var z := float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
    var input_vec := Vector2(x, z)

    var moving := input_vec.length() > 0.01
    if moving:
        input_vec = input_vec.normalized()

        var direction := (player.transform.basis * Vector3(input_vec.x, 0, input_vec.y)).normalized()
        player.velocity.x = direction.x * speed
        player.velocity.z = direction.z * speed
    else:
        player.velocity.x = move_toward(player.velocity.x, 0.0, speed * 8.0 * delta)
        player.velocity.z = move_toward(player.velocity.z, 0.0, speed * 8.0 * delta)

    if not player.is_on_floor():
        player.velocity.y -= 12.0 * delta
    else:
        player.velocity.y = 0.0

    player.move_and_slide()

    if anim_player and not action_playing:
        if moving:
            _play_animation_containing(["jog", "walk", "run"])
        else:
            if anim_player.is_playing() and ("jog" in anim_player.current_animation.to_lower() or "walk" in anim_player.current_animation.to_lower()):
                anim_player.stop()

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

    var names := anim_player.get_animation_list()
    for name in names:
        var lower := name.to_lower()
        if "kettlebell" in lower or "swing" in lower:
            action_playing = true
            anim_player.play(name)
            await anim_player.animation_finished
            action_playing = false
            return

    # If the imported animation has another name, play the first animation.
    if names.size() > 0:
        action_playing = true
        anim_player.play(names[0])
        await anim_player.animation_finished
        action_playing = false
