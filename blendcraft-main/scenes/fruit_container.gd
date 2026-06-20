extends Control

@export var fruit_name: String = "cherry"
@export var fruit_count: int = 6
@onready var pickup_zone = $PickupZone
@onready var fruit_grid = $FruitGridContainer
@onready var container_image = $ContainerImg
const PhysicsFruit = preload("res://scenes/physics_fruit.tscn")
var _active_fruit = null

func _ready():
	# signals
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_build_fruits()
	_update_cursor()
	
	container_image.pivot_offset = container_image.size / 2 # offset for hover animation
func _update_cursor():
	if get_global_rect().has_point(get_global_mouse_position()):
		if fruit_count > 0:
			mouse_default_cursor_shape = CURSOR_POINTING_HAND
			if not (_active_fruit and is_instance_valid(_active_fruit) and _active_fruit.is_dragging):
				_scale_image_up()
		else:
			mouse_default_cursor_shape = CURSOR_ARROW
	else:
		mouse_default_cursor_shape = CURSOR_ARROW

func _on_mouse_entered():
	_update_cursor()

func _on_mouse_exited():
	if _active_fruit and is_instance_valid(_active_fruit) and _active_fruit.is_dragging:
		return
	mouse_default_cursor_shape = CURSOR_ARROW
	_scale_image_down()

func _scale_image_up(): # animation for hovering container
	var tween = create_tween()
	tween.tween_property(container_image, "scale", Vector2(1.05, 1.05), 0.1)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _scale_image_down(): # animation for hovering container
	var tween = create_tween()
	tween.tween_property(container_image, "scale", Vector2(1.0, 1.0), 0.1)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _gui_input(event): # pick up fruit if clicking on pickup zone with fruit
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if fruit_count > 0:
				_spawn_dragging_fruit()

func _spawn_dragging_fruit(): # pick up fruit
	remove_one_fruit() 
	
	var fruit = PhysicsFruit.instantiate()
	fruit.fruit_name = fruit_name
	fruit.source_container = self
	fruit.position = get_global_mouse_position()
	fruit.start_dragging()
	get_tree().current_scene.add_child(fruit)
	_active_fruit = fruit # set active fruit ref
	_scale_image_down()
func remove_one_fruit(): # remove fruit from pickup zone

	_update_cursor()

func add_one_fruit(): # add a fruit back to pickup zone

	_build_fruits()
	_update_cursor()

func setup(name: String, count: int): # init
	fruit_name = name
	fruit_count = count
	_build_fruits()

func _build_fruits(): # set fruit png
	var fruit_list = [["cherry", "#ff0000"], ["blueberry", "#0000ff"], ["kale", "#00ff00"], ["Strawberry", "#ffa3cb"], ["Banana", "#fff563"], ["Orange", "#ff901d"]]
	for child in fruit_grid.get_children():
		child.queue_free()
	if true:#fruit_name == "cherry":
		#var texture = load("res://assets/fruits/" + fruit_name + "_container.png")
		var texture = load("res://assets/fruits/cherry_container.png")
		container_image.texture = texture
		for i in fruit_list:
			if i[0] == fruit_name:
				container_image.modulate = i[1]
		
	#else:
	#	var texture = load("res://assets/container.png")
	#	container_image.texture = texture
