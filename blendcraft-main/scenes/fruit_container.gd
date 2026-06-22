extends Control

@export var fruit_name: String = "cherry"
@export var fruit_count: int = 6
@onready var pickup_zone = $PickupZone
@onready var fruit_grid = $FruitGridContainer
@onready var container_bottom = $Img/Container_Bottom
@onready var container_top = $Img/Container_Top
@onready var container_fruit = $Img/Container_All_Fruit
@onready var container_img = $Img
const PhysicsFruit = preload("res://scenes/physics_fruit.tscn")
var _active_fruit = null
var fruit_list = [["cherry", "#ff0000"], ["blueberry", "#0000ff"], ["kale", "#00ff00"], ["strawberry", "#ffa3cb"], ["banana", "#fff563"]]#, ["orange", "#ff901d"]]

func _ready():
	# signals
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_build_fruits()
	#_update_cursor()
	
	container_img.pivot_offset = container_img.size / 2 # offset for hover animation
	container_fruit.pivot_offset = container_fruit.size / 2 # offset for hover animation
	container_top.pivot_offset = container_top.size / 2 # offset for hover animation
	container_bottom.pivot_offset = container_bottom.size / 2 # offset for hover animation
'''
func _update_cursor():
	#print(get_parent().get_parent().ready_to_point_hand )
	if get_global_rect().has_point(get_global_mouse_position()):
		if fruit_count > 0:
			
			#if get_parent().get_parent().on_main_menu == false:
			#get_parent().get_parent().ready_to_point_hand = false
			mouse_default_cursor_shape = CURSOR_POINTING_HAND
			if not (_active_fruit and is_instance_valid(_active_fruit) and _active_fruit.is_dragging):
				_scale_image_up()
			#else:
				#get_parent().get_parent().ready_to_point_hand = true
				#pass
				
		else: #theoretical, i dont think this will happen yet
			#get_parent().get_parent().ready_to_point_hand = false
			mouse_default_cursor_shape = CURSOR_ARROW
			#get_parent().get_parent().ready_to_point_hand = false
	else:
		mouse_default_cursor_shape = CURSOR_ARROW
		
		#get_parent().get_parent().ready_to_point_hand = false
'''

func point(hand):
	if hand == true:
		mouse_default_cursor_shape = CURSOR_POINTING_HAND
	else:
		mouse_default_cursor_shape = CURSOR_ARROW

func _on_mouse_entered():
	get_parent().get_parent().ready_to_point_hand_special = self
	if get_parent().get_parent().on_main_menu == true:
		return
	if _active_fruit and is_instance_valid(_active_fruit) and _active_fruit.is_dragging:
		get_parent().get_parent().last_container_hover = self
		return
	if get_parent().get_parent().hands_full == true:
		get_parent().get_parent().last_container_hover = self
		return
	else:
		get_parent().get_parent().last_container_hover = null
	mouse_default_cursor_shape = CURSOR_POINTING_HAND
	get_parent().get_parent().update_shader_mode(1, fruit_name, true)
	#Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
	#get_parent().get_parent().mouse_hover()
	_scale_image_up()
	

func _on_mouse_exited():
	get_parent().get_parent().last_container_hover = null
	if get_parent().get_parent().on_main_menu == true:
		return
	if _active_fruit and is_instance_valid(_active_fruit) and _active_fruit.is_dragging:
		return
	#get_parent().get_parent().mouse_unhover()
	#Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	mouse_default_cursor_shape = CURSOR_ARROW
	get_parent().get_parent().update_shader_mode(0, fruit_name)
	_scale_image_down()

func _scale_image_up(): # animation for hovering container
	var tween = create_tween()
	tween.tween_property(container_img, "scale", Vector2(1.05, 1.05), 0.1)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	#tween.tween_property(container_image2, "scale", Vector2(1.05, 1.05), 0.1)\
	#	.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _scale_image_down(): # animation for hovering container
	var tween = create_tween()
	tween.tween_property(container_img, "scale", Vector2(1.0, 1.0), 0.1)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	#tween.tween_property(container_image2, "scale", Vector2(1.0, 1.0), 0.1)\
	#	.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _gui_input(event): # pick up fruit if clicking on pickup zone with fruit
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if get_parent().get_parent().on_main_menu == false:
				if fruit_count > 0:
					_spawn_dragging_fruit()

func _spawn_dragging_fruit(): # pick up fruit
	remove_one_fruit() 
	
	var fruit = PhysicsFruit.instantiate()
	fruit.fruit_name = fruit_name
	fruit.source_container = self
	fruit.position = get_global_mouse_position()
	fruit.start_dragging()
	if [1,2].pick_random() == 1:
		fruit.get_node("FruitImage").flip_h = true
		fruit.get_node("FruitImageStem").flip_h = true
	
		#texture = load("res://assets/fruits/fruit_" + fruit_name + "_white.png")
		#texture2 = load("res://assets/fruits/fruit_" + fruit_name + "_stem.png")
		
	get_tree().current_scene.add_child(fruit)
	_active_fruit = fruit # set active fruit ref
	_scale_image_down()
	get_parent().get_parent().entities_list.append(fruit)
	get_parent().get_parent().hands_full = true
	#get_parent().get_parent().get_node("Color_Triangle/Triangle/" + fruit_name).material.set_shader_parameter("mode", 1)
	get_parent().get_parent().update_shader_mode(1, fruit_name, true)
	get_parent().get_parent().last_container_hover = self
	
func remove_one_fruit(): # remove fruit from pickup zone
	pass
	#_update_cursor()

func add_one_fruit(): # add a fruit back to pickup zone

	_build_fruits()
	#_update_cursor()

func setup(name: String, count: int): # init
	fruit_name = name
	fruit_count = count
	_build_fruits()

func _build_fruits(): # set fruit png
	for child in fruit_grid.get_children():
		child.queue_free()
	for i in container_fruit.get_children():
		var texture
		var texture2
		if [1,2,3,4,5].pick_random() in [1,2]:
			if ResourceLoader.exists("res://assets/fruits/fruit_" + fruit_name + "_white2.png"):
				texture = load("res://assets/fruits/fruit_" + fruit_name + "_white2.png")
			else:
				texture = load("res://assets/fruits/fruit_" + fruit_name + "_white.png")
			if ResourceLoader.exists("res://assets/fruits/fruit_" + fruit_name + "_stem2.png"):
				texture2 = load("res://assets/fruits/fruit_" + fruit_name + "_stem2.png")
			else:
				texture2 = null#load("res://assets/fruits/fruit_" + fruit_name + "_stem.png")
		else:
			texture = load("res://assets/fruits/fruit_" + fruit_name + "_white.png")
			texture2 = load("res://assets/fruits/fruit_" + fruit_name + "_stem.png")
		
		i.texture = texture
		i.self_modulate = get_parent().get_parent().fruits_colors[fruit_name]
		i.get_node("Container_Stem_1").texture = texture2
		#new_seed
		if [1,2].pick_random() == 1:
			i.flip_h = true
			i.get_node("Container_Stem_1").flip_h = true
		if fruit_name == "blueberry":
			i.position.y += 10
		#if fruit_name == "kale":
		#	i.position.x += 2
		
	#else:
	#	var texture = load("res://assets/container.png")
	#	container_image.texture = texture
#func _release(): #just to make the cursor update upon restart seamless between queue_freeing fruit_containers and physics_fruit
#	pass
