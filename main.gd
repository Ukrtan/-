extends Node3D

var player: CharacterBody3D
var first_camera: Camera3D
var third_camera: Camera3D
var body: Node3D
var anim_player: AnimationPlayer
var third_person := false
var speed := 3.5
var mouse_sensitivity := 0.0025
var pitch := 0.0
var yaw := 0.0

func _ready():
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
    _make_room()
    _make_player()
    _try_load_models()

func _unhandled_input(event):
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        yaw -= event.relative.x * mouse_sensitivity
        pitch = clamp(pitch - event.relative.y * mouse_sensitivity, -1.45, 1.45)
        player.rotation.y = yaw
        first_camera.rotation.x = pitch
        third_camera.rotation.x = pitch * 0.75
    elif event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_ESCAPE:
            Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
        elif event.keycode == KEY_V:
            third_person = !third_person
            first_camera.current = !third_person
            third_camera.current = third_person
        elif event.keycode == KEY_C:
            _play_kettlebell()

func _physics_process(delta):
    if not player:
        return
    var input_vec = Input.get_vector("move_left","move_right","move_forward","move_back")
    var dir = (player.transform.basis * Vector3(input_vec.x,0,input_vec.y)).normalized()
    if dir:
        player.velocity.x = dir.x * speed
        player.velocity.z = dir.z * speed
    else:
        player.velocity.x = move_toward(player.velocity.x,0,speed*8.0*delta)
        player.velocity.z = move_toward(player.velocity.z,0,speed*8.0*delta)
    if not player.is_on_floor():
        player.velocity.y -= 12.0 * delta
    else:
        player.velocity.y = 0
    player.move_and_slide()

func _make_player():
    player = CharacterBody3D.new()
    player.name = "Player"
    add_child(player)
    
    var collision = CollisionShape3D.new()
    var capsule = CapsuleShape3D.new()
    capsule.height = 1.8
    capsule.radius = 0.35
    collision.shape = capsule
    collision.position.y = 0.9
    player.add_child(collision)
    
    first_camera = Camera3D.new()
    first_camera.name = "FirstPersonCamera"
    first_camera.position = Vector3(0,1.6,0)
    first_camera.current = true
    player.add_child(first_camera)
    
    third_camera = Camera3D.new()
    third_camera.name = "ThirdPersonCamera"
    third_camera.position = Vector3(0,2.2,4.5)
    third_camera.rotation_degrees.y = 180
    third_camera.current = false
    player.add_child(third_camera)
    
    body = Node3D.new()
    body.name = "Body"
    player.add_child(body)

func _make_room():
    var floor = StaticBody3D.new()
    floor.name = "Floor"
    add_child(floor)
    var shape = CollisionShape3D.new()
    var box = BoxShape3D.new()
    box.size = Vector3(14,0.2,14)
    shape.shape = box
    shape.position.y = -0.1
    floor.add_child(shape)
    
    var mesh = MeshInstance3D.new()
    var plane = BoxMesh.new()
    plane.size = Vector3(14,0.2,14)
    mesh.mesh = plane
    mesh.position.y = -0.1
    floor.add_child(mesh)
    
    for data in [
        [Vector3(0,2.0,-7),Vector3(14,4,0.2)],
        [Vector3(0,2.0,7),Vector3(14,4,0.2)],
        [Vector3(-7,2.0,0),Vector3(0.2,4,14)],
        [Vector3(7,2.0,0),Vector3(0.2,4,14)]
    ]:
        _make_wall(data[0],data[1])

func _make_wall(pos:Vector3,size:Vector3):
    var wall = StaticBody3D.new()
    add_child(wall)
    var col = CollisionShape3D.new()
    var box = BoxShape3D.new()
    box.size = size
    col.shape = box
    col.position = pos
    wall.add_child(col)
    var mesh = MeshInstance3D.new()
    var visual = BoxMesh.new()
    visual.size = size
    mesh.mesh = visual
    mesh.position = pos
    wall.add_child(mesh)

func _try_load_models():
    var room_path = "res://assets/комната для игры.glb"
    if ResourceLoader.exists(room_path):
        var scene = load(room_path)
        if scene:
            var room = scene.instantiate()
            room.name = "ImportedRoom"
            add_child(room)
    
    var jogging_path = "res://assets/Jogging.fbx"
    if ResourceLoader.exists(jogging_path):
        var scene = load(jogging_path)
        if scene:
            var model = scene.instantiate()
            model.name = "JoggingModel"
            model.visible = false
            body.add_child(model)
            _find_animation_player(model)
    
    var swing_path = "res://assets/Kettlebell Swing.fbx"
    if ResourceLoader.exists(swing_path):
        var scene = load(swing_path)
        if scene:
            var model = scene.instantiate()
            model.name = "KettlebellSwingSource"
            model.visible = false
            body.add_child(model)
            _find_animation_player(model)

func _find_animation_player(node):
    if node is AnimationPlayer:
        anim_player = node
        return
    for child in node.get_children():
        _find_animation_player(child)

func _play_kettlebell():
    if anim_player:
        var names = anim_player.get_animation_list()
        for n in names:
            if "kettlebell" in n.to_lower() or "swing" in n.to_lower():
                anim_player.play(n)
                return
        if names.size() > 0:
            anim_player.play(names[0])
