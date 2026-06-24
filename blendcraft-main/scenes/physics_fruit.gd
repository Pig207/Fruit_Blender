extends RigidBody2D

var fruit_name: String = ""
var source_container = null
var is_dragging: bool = false

# throw physics
const VELOCITY_HISTORY_SIZE = 5
const THROW_MULTIPLIER = 1
const MIN_THROW_SPEED = 1.0
const MAX_THROW_SPEED = 1100.0
var mouse_velocity_history: Array = []
var last_mouse_pos: Vector2 = Vector2.ZERO

# snapping from barriers after no longer blocked
const BARRIER_SNAP_SPEED = 2000.0  # pixels/sec to mouse when no longer blocked
var clamped_drag_pos: Vector2 = Vector2.ZERO 

# rotation on release
const THROW_ROTATION_FACTOR = 0.003   # rotation factor based on throw speed
const DROP_ROTATION_FACTOR  = 1.2     # max rotation factor for dropping (rand in range)

@onready var sprite            = $FruitImage
@onready var sprite2           = $FruitImageStem
@onready var fruit_hitbox      = $FruitHitbox
@onready var settle_detector   = $BarCollisionDetector
@onready var settle_shape      = $BarCollisionDetector/CollisionShape2D

var fruit_list = [["cherry", "#ff0000"], ["blueberry", "#0000ff"], ["kale", "#00ff00"], ["strawberry", "#ffa3cb"], ["banana", "#fff563"]]#, ["orange", "#ff901d"]]

func _ready():
	#print('initializing physics_fruit')
	freeze = true # fruit affected by physics or not (dragging)
	input_pickable = true # fruit interactable w mouse
	self.name = fruit_name
	settle_detector.area_entered.connect(_on_entered_container_zone) # signal for landing on fruit container
	mouse_entered.connect(_on_mouse_entered) # mouse hovering fruit
	mouse_exited.connect(_on_mouse_exited) # mouse no longer hovering fruit 
	#sprite.texture = load("res://assets/fruits/" + fruit_name + ".png")
	var rand_val = [1,2,3,4,5].pick_random()
	if rand_val in [1,2]:
		var texture1
		var texture2
		if ResourceLoader.exists("res://assets/fruits/fruit_" + fruit_name + "_white2.png"):
			texture1 = load("res://assets/fruits/fruit_" + fruit_name + "_white2.png")
		else:
			texture1 = load("res://assets/fruits/fruit_" + fruit_name + "_white.png")
		if ResourceLoader.exists("res://assets/fruits/fruit_" + fruit_name + "_stem2.png"):
			texture2 = load("res://assets/fruits/fruit_" + fruit_name + "_stem2.png")
		else:
			texture2 = null#load("res://assets/fruits/fruit_" + fruit_name + "_stem.png")
		sprite.texture = texture1
		sprite2.texture = texture2
	else:
		if rand_val in [3] and ResourceLoader.exists("res://assets/fruits/fruit_" + fruit_name + "_white3.png"):
			sprite.texture = load("res://assets/fruits/fruit_" + fruit_name + "_white3.png")
			sprite2.texture = null #just bananas for now
		else:
			sprite.texture = load("res://assets/fruits/fruit_" + fruit_name + "_white.png")
			sprite2.texture = load("res://assets/fruits/fruit_" + fruit_name + "_stem.png")
	#self.material = pulse_shader
	#pulse_mat.set_shader_parameter("mode", 2)
	#pulse_shader = load("res://scenes/color_target_pulse.gdshader")
	#pulse_mat = get_parent().get_node("Color_Triangle/Triangle/" + fruit_name).material# as ShaderMaterial
	#pulse_mat.shader = pulse_shader
	#for i in fruit_list:
	#	if i[0] == fruit_name:
	#get_parent().fruits_colors[fruit_name]
	sprite.modulate = get_parent().fruits_colors[fruit_name]
	_apply_hitbox_shapes()

func _on_mouse_entered(): # set clicky cursor hovering fruit
	if not is_dragging:
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
		#var target = get_parent().get_node("Color_Triangle/Triangle/" + fruit_name)
		#var color = get_parent().fruits_colors[fruit_name]
		#get_parent().darken_target(target, color, 1.0)
		#target.material.set_shader_parameter("mode", 1)

func _on_mouse_exited(): # reset cursor leaving fruit
	if not is_dragging:
		if get_parent():
			if get_parent().mouse_on_color_triangle == true:
				return
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		

func _input_event(_viewport, event, _shape_idx): # pick up fruit (off ground/midair etc)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not is_dragging:
			start_dragging()
			get_viewport().set_input_as_handled()

func start_dragging(): # start holding fruit in mouse
	is_dragging = true
	freeze = true
	if get_parent():
		get_parent().hands_full = is_dragging
		get_parent().update_shader_mode(1, fruit_name, true)
		#get_parent().get_node("Color_Triangle/Triangle/" + fruit_name).material.set_shader_parameter("mode", 1.0)
	linear_velocity  = Vector2.ZERO
	angular_velocity = 0
	mouse_velocity_history.clear()
	last_mouse_pos   = get_global_mouse_position()
	
	clamped_drag_pos = global_position # track position to check for clamping against barriers

func _process(delta): 
	
# update fruit pos each tick based on mouse and whether its clamped/blocked somewhere
# track when released, and track recent mouse movement for throw variables

	if is_dragging:
		var mouse_pos = get_global_mouse_position()
		#check where mouse WANTS to go
		var target_pos = clamped_drag_pos.move_toward(mouse_pos, BARRIER_SNAP_SPEED * delta)
		var motion = target_pos - global_position

		# test what motion is allowed based on where barriers are
		var safe_motion = _test_motion_against_barriers(motion)
		
		# apply allowed movement
		clamped_drag_pos = global_position + safe_motion
		global_position = clamped_drag_pos

		# track mouse velocity for throwing
		var frame_velocity = (mouse_pos - last_mouse_pos) / delta
		mouse_velocity_history.append(frame_velocity)
		if mouse_velocity_history.size() > VELOCITY_HISTORY_SIZE:
			mouse_velocity_history.pop_front()
		last_mouse_pos = mouse_pos

		if Input.is_action_just_released("left_click"):
			_release()
	#if Input.is_action_just_released("r"):
	#	queue_free()

# test what amt of desired motion is allowed based on where barriers are
func _test_motion_against_barriers(motion: Vector2) -> Vector2:
	if motion == Vector2.ZERO:
		return Vector2.ZERO
	
	# motion simulator parameters
	var params = PhysicsTestMotionParameters2D.new()
	
	# start at fruit pos, test the desired motion, exclude self
	params.from = global_transform
	params.motion = motion
	params.exclude_bodies = [get_rid()] 
	var result = PhysicsTestMotionResult2D.new()
	
	# collided is boolean, get_rid specifies the body its testing, 
	# params is the motion, result stores info about the collision (if any)
	
	var collided = PhysicsServer2D.body_test_motion(get_rid(), params, result)

	if collided:
		
		# desired movement minus how much was blocked
		var safe_travel = motion - result.get_remainder()
		
		# slide to meet other axis movement if stuck
		var remainder = result.get_remainder()
		var normal = result.get_collision_normal()
		var slide_motion = remainder.slide(normal)
		
		return safe_travel + slide_motion
	
	return motion

func _release(): # apply release velocity&rotation to fruit
	is_dragging      = false
	freeze           = false
	if get_parent():
		get_parent().hands_full = is_dragging
		#print(str(get_parent().last_container_hover))
		if get_parent().last_container_hover != null:
			get_parent().last_container_hover._on_mouse_entered()
		else:
			get_parent().update_shader_mode(0, fruit_name)
			
		#get_parent().get_node("Color_Triangle/Triangle/" + fruit_name).material.set_shader_parameter("mode", 0.0)

	var throw_velocity = _calculate_throw_velocity()

	# fruit rotation on throw
	if throw_velocity.length() > MIN_THROW_SPEED:
		linear_velocity  = throw_velocity
		# proportional to speed, and matches the side it was thrown
		angular_velocity = throw_velocity.length() * THROW_ROTATION_FACTOR * sign(throw_velocity.x) * 1.2 #arbitrary, idk lol
	else:
		linear_velocity  = Vector2(0, 10)
		# slight random spin when dropped
		angular_velocity = randf_range(-DROP_ROTATION_FACTOR, DROP_ROTATION_FACTOR)

func _calculate_throw_velocity() -> Vector2: # calculate throw based on recent mouse movement
	if mouse_velocity_history.is_empty():
		return Vector2.ZERO

	var avg = Vector2.ZERO
	for v in mouse_velocity_history:
		avg += v
	avg /= mouse_velocity_history.size()

	var result = avg * THROW_MULTIPLIER
	if result.length() > MAX_THROW_SPEED:
		result = result.normalized() * MAX_THROW_SPEED
	return result



func _on_entered_container_zone(area): # add fruit back to container when it lands on/near proper container
	if not is_dragging:
		if area.is_in_group("container_zone"):
			var container = area.get_parent()
			if container.fruit_name == fruit_name:
				container.add_one_fruit()
				#Input.set_default_cursor_shape(Input.CURSOR_ARROW)
				queue_free()


func _apply_hitbox_shapes(): # apply fruit hitbox for given fruit
	var shape = _get_fruit_shape(fruit_name)
	if shape == null:
		push_warning("No hitbox defined for fruit: " + fruit_name)
		return
	fruit_hitbox.shape  = shape
	settle_shape.shape  = shape

func _get_fruit_shape(name: String) -> Shape2D: # dif fruit hitboxes
	match name:
		"cherry":
			var s    = CapsuleShape2D.new()
			s.radius = 14
			s.height = 40
			return s
		"blueberry":
			var s    = CapsuleShape2D.new()
			s.radius = 14
			s.height = 40
			return s
		"kale":
			var s    = CapsuleShape2D.new()
			s.radius = 14
			s.height = 40
			return s
		"strawberry":
			var s    = CapsuleShape2D.new()
			s.radius = 14
			s.height = 40
			return s
		"banana":
			var s    = CapsuleShape2D.new()
			s.radius = 14
			s.height = 40
			return s
	return null
