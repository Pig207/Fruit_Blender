# Main.gd
extends Node

var fruits: Dictionary = {
	"cherry": 4,
	"kale": 4,
	"blueberry": 4,
	"strawberry": 4,
	"banana": 4
}
var fruits_colors: Dictionary = {
	"cherry": Color("#ff0000"),
	"kale": Color("#00ff00"),
	"blueberry": Color("#0000ff"),
	"strawberry": Color("#ffa3cb"),
	"banana": Color("#fff563")
}
var in_blender = []
var blended_fruits = []
var maximize_brightness = true #change to false for old mode
var current_blend_color = Color("#ffffff00")
var walking = false
var waiting_to_walk = 0
var possible_sizes = [["Small", 2], ["Small", 2], ["Small", 2], ["Medium", 3], ["Medium", 3], ["Large", 5]]
var fruit_list = [["cherry", "#ff0000"], ["blueberry", "#0000ff"], ["kale", "#00ff00"], ["banana", "#fff563"], ["strawberry", "#ffa3cb"]]#, ["orange", "#ff901d"]]
var target_color
var percentage_similarity = 0
var current_size = ["Large", 5]
var thanking = false
var mouse_on_blender_button = false
var total_smoothie_count = 0
var snappyfied = false
var triangle_corners
var on_main_menu = true
var entities_list = []
var mouse_on_color_triangle = false
var color_triangle_toggled_on = false
var hands_full = false
var ready_to_point_hand = false
var ready_to_point_hand_special = null
var shaders_to_update = []
var last_container_hover = null
var all_text_nodes = []

# da blenda animation
# Configuration variables
var blend_duration: float = 0.5  # Total time in seconds
var max_shake: float = 0.3      # Maximum rotation burst (in radians, ~20 degrees)
var blend_speed: float = 120.0   # High frequency for aggressive back-and-forth
# Tracking variables
var blend_timer: float = 0.0
var is_blending: bool = false
@onready var base_rotation: float = 0.0 # Store original rotation
# Configuration variables 2 (for dumping)
var blend_duration2: float = 0.3  # Total animation time
var max_compress2: float = 0.1   # Squashes down by 15% at its peak
# Tracking variables
var blend_timer2: float = 0.0
var is_dumping: bool = false
@onready var base_scale_y2: float = 0.519043

@onready var fruit_slot_area = $GridOfContainers  # your HBoxContainer
const FruitContainer = preload("res://scenes/fruit_container.tscn")

var people_speed: float = 3.0
#var people_bob_speed: float = 12.0     # How fast it steps up and down
var people_bob_height: float = 15.0    # How high the bounce goes
var people_list = [$person1, $person2]

func _ready():
	randomize()
	apply_fonts()
	start_game()
	
func _physics_process(delta: float):
	#print(ready_to_point_hand)
	update_shaders(delta)
	if on_main_menu == true:
		if Input.is_action_just_released("either_click"):
			$Menu.visible = false
			$UI_Labels.visible = true
			on_main_menu = false
			if ready_to_point_hand == true:
				#ready_to_point_hand = false
				Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
			if ready_to_point_hand_special != null:
				ready_to_point_hand_special.point(true)
				#ready_to_point_hand_special = null
			#start_game()
		return
	if walking == true:
		if people_list[waiting_to_walk].position.x < 570:
			for p in people_list:
				p.position.x += people_speed
				var bounce = abs(sin(p.position.x)) * people_bob_height
				p.position.y = 250 - bounce
		else:
			walking = false
			$Request.modulate = target_color
			$Request_Label.visible = true
			
			if total_smoothie_count == 3 and $Snappy_Timer.is_stopped():
				$Snappy_Timer.start()
			
	if Input.is_action_just_pressed("left_click"):
		if mouse_on_blender_button == true:
			mouse_on_color_triangle = false
			start_blending()
			blend()
		elif mouse_on_color_triangle == true and hands_full == false:
			if color_triangle_toggled_on == false:
				color_triangle_toggled_on = true
				$Color_Triangle.modulate = Color("#ffffff")
			else:
				color_triangle_toggled_on = false
				$Color_Triangle.modulate = Color("#ffffff3c")#Color("ffffff78")
	
	if Input.is_action_just_pressed("r"):
		for ent in entities_list:
			if ent:
				#print(ent.name)
				#if ent.has_method("_release"):
				#	if ent.is_dragging == true:
				ent.queue_free()
				
		entities_list = []
		_ready()
		
	if is_blending:
		# Tick down the timer (1/60th of a second per physics frame)
		blend_timer -= delta
		
		if blend_timer <= 0:
			# Stop blending and reset cleanly to base position
			is_blending = false
			$Blendernolid.rotation = base_rotation
		else:
			# 1. Calculate how far along we are (0.0 at start, 1.0 at end)
			var progress = 1.0 - (blend_timer / blend_duration)
			
			# 2. Tapering curve: Exponential decay (pow) drops the power violently at first
			# then smoothly transitions back to zero.
			var taper = pow(1.0 - progress, 3.0) 
			
			# 3. Aggressive rapid oscillation using a fast sine wave
			var shake_wave = sin(blend_timer * blend_speed)
			
			# Apply the fast shake multiplied by the violent taper
			$Blendernolid.rotation = base_rotation + (shake_wave * max_shake * taper)
	if is_dumping:
		blend_timer2 += delta
		
		if blend_timer2 >= blend_duration2:
			is_dumping = false
			$Blendernolid.scale.y = base_scale_y2
		else:
			# 1. Get a clean 0.0 to 1.0 progress value
			var progress = blend_timer2 / blend_duration2
			var squash_factor: float = 0.0
			
			# 2. Split the 0.5s into two distinct halves:
			if progress < 0.5:
				# FIRST HALF (0.0 -> 0.25s): Squash down smoothly
				# Map 0.0-0.5 progress into a 0.0-1.0 curve
				var t = progress / 0.5 
				squash_factor = ease(t, -2.0) # -2.0 gives it an "ease-out" weight
			else:
				# SECOND HALF (0.25s -> 0.5s): Return to normal height
				# Map 0.5-1.0 progress into a 1.0-0.0 curve
				var t = (progress - 0.5) / 0.5
				squash_factor = ease(1.0 - t, 2.0) # 2.0 creates a snappy return
			
			# 3. Apply the single compression stroke
			$Blendernolid.scale.y = base_scale_y2 - (squash_factor * max_compress2)
	
func start_game():
	on_main_menu = true
	$Menu.visible = true
	$UI_Labels.visible = false
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	
	shaders_to_update = []
	in_blender = []
	blended_fruits = []
	$Thanks_Timer.stop()
	$Snappy_Timer.stop()
	total_smoothie_count = 0
	$UI_Labels/Points.text = str(total_smoothie_count-1)
	$UI_Labels/Percent_Correct.text = "0%"
	$UI_Labels/Percent_Correct.visible = false
	$UI_Labels/Blender_Size.text = "0"
	people_list = [$person1, $person2]
	triangle_corners = get_corner_positions()
	generate_new_color()
	_build_fruit_containers(["blueberry", "kale", "cherry"])
	$Blendernolid/BlenderFull.modulate = Color("#ffffff00")
	$Request.modulate = Color("#ffffff00")
	$Request_Label.visible = false
	setup_Done()
	setup_Dump()
	setup_people()
	get_node("Color_Triangle/Triangle/Target").position = set_target_on_triangle(Color("#ffffff"))
	$Color_Triangle.modulate = Color("#ffffff3c")
	if ready_to_point_hand_special != null:
		ready_to_point_hand_special.point(false)

# add all the fruits in a given fruit dish to the grid container
func _build_fruit_containers(arra):
	for fruit_name in arra: #fruits:
		#print(fruit_name)
		#print(fruits[fruit_name])
		var container = FruitContainer.instantiate()
		fruit_slot_area.add_child(container)
		container.setup(fruit_name, fruits[fruit_name])
		entities_list.append(container)
		
		var central_target = $Color_Triangle/Triangle/Target
		#for i in fruit_list:
		#	if i[0] == fruit_name:
		#fruits_colors[fruit_name]
				#print(i[0])
		var color_target = central_target.duplicate()
		$Color_Triangle/Triangle.add_child(color_target)
		color_target.position = set_target_on_triangle(fruits_colors[fruit_name])
		entities_list.append(color_target)
		#color_target.modulate = Color(i[1]).darkened(0.5)
		darken_target(color_target, fruits_colors[fruit_name], 0.7)
		color_target.z_index -= 1
		color_target.name = fruit_name
		
		var pulse_mat = ShaderMaterial.new()
		pulse_mat.shader = load("res://scenes/color_target_pulse.gdshader")
		color_target.material = pulse_mat
		color_target.material.set_shader_parameter("mode", 0.0)
		color_target.material.set_shader_parameter("shine_color", (fruits_colors[fruit_name].lightened(0.9)))
		#material.set_shader_parameter("mode", 0.0)
		shaders_to_update.append([color_target, 0.0, 0.0, 6, fruit_name, 0.0])
				
func update_shader_mode(new_mode, name_fruit, reset_time = false):
	for shader_target in shaders_to_update:
		if shader_target[4] == name_fruit:
			if shader_target[2] != float(new_mode):
				shader_target[2] = float(new_mode)
				#shader_target[0].material.set_shader_parameter("mode", float(new_mode))
				if reset_time == true:
					shader_target[5] = 1.0
				
func update_shaders(delta):
	for shader_target in shaders_to_update:
		var current_mode_blend = shader_target[1]
		var target_mode = shader_target[2]
		var transition_speed = shader_target[3]
		shader_target[5] += delta
		shader_target[0].material.set_shader_parameter("custom_time", shader_target[5])
		
		if current_mode_blend != target_mode:
		
			
			# Smoothly slide the value toward the target mode
			current_mode_blend = move_toward(current_mode_blend, target_mode, transition_speed * delta)
			
			# Send the updated float to the shader
			#print(current_mode_blend)
			shader_target[1] = current_mode_blend
			shader_target[0].material.set_shader_parameter("mode", current_mode_blend)
				
func darken_target(target, color, darkness):
	target.modulate = color.darkened(darkness)

func _on_detect_fruit_body_entered(body: Node2D) -> void:
	in_blender.append(body)

func _on_detect_fruit_body_exited(body: Node2D) -> void:
	#print("exit: " + str(body))
	if in_blender != []:
		for i in in_blender:
			if i == body:
				in_blender.erase(body)

func start_blending():
	blend_timer = blend_duration
	is_blending = true
	
func start_dumping():
	blend_timer2 = 0.0 # Count UP from 0 to 0.5
	is_dumping = true

func blend(dumpin = false):
	
	if thanking == true:
		return
	var fruits = ["cherry", "blueberry", "kale", "strawberry", "banana"]
	var goners = []
	for i in in_blender:
		for j in fruits:
			if j in i.name:
				if dumpin == false:
					blended_fruits.append(j)
				goners.append(i)

	for i in goners:
		in_blender.erase(i)
		i.queue_free()
		
	if blended_fruits  != []:
		current_blend_color = average_color_list(blended_fruits)
		if len(blended_fruits) <= 5:
			$Blendernolid/BlenderFull.texture = load("res://assets/blenderglass_white" + str(len(blended_fruits)) + ".png")
		else:
			$Blendernolid/BlenderFull.texture = load("res://assets/blenderglass_white5.png")
		$Blendernolid/BlenderFull.modulate = current_blend_color
		
		percentage_similarity = (get_color_similarity(current_blend_color, target_color))
		if percentage_similarity < 10:
			$UI_Labels/Percent_Correct.text = "%01d" % [percentage_similarity] + "%"
		else:
			$UI_Labels/Percent_Correct.text = "%02d" % [percentage_similarity] + "%"
		$UI_Labels/Percent_Correct.visible = true
		$UI_Labels/Blender_Size.text = str(len(blended_fruits))
		if percentage_similarity == 100.0 and ((len(blended_fruits)) >= current_size[1]) and $Thanks_Timer.is_stopped() == true:
			$Thanks_Timer.start()
			#$Request.modulate = target_color
			thanking = true
			if total_smoothie_count < 3:
				$Request_Label.text = ["Thanks!", "Thank you!", "Perfect!"].pick_random()
			else:
				$Request_Label.text = ["Thanks!", "Thank you!", "About time...", "Perfect!"].pick_random()
	get_node("Color_Triangle/Triangle/Target").position = set_target_on_triangle(current_blend_color)
				
func average_color_list(blended_fruits):
	var colors = []
	for fruit_name in blended_fruits:
		#for j in fruit_list:
		#	if i == j[0]:
		colors.append(fruits_colors[fruit_name])
	
	var count = colors.size()
	if count == 0:
		return Color.BLACK # Fallback for empty list
	if count == 1:
		return colors[0]

	var total_r := 0.0
	var total_g := 0.0
	var total_b := 0.0
	var total_a := 0.0

	# Accumulate the squares of the channels to preserve perceived brightness
	for color in colors:
		total_r += color.r * color.r
		total_g += color.g * color.g
		total_b += color.b * color.b
		total_a += color.a # Alpha averages linearly

	# Divide by total and take the square root
	var final_r = sqrt(total_r / count)
	var final_g = sqrt(total_g / count)
	var final_b = sqrt(total_b / count)
	var final_a = total_a / count

	# --- OPTIONAL SCALING CLAUSE ---
	if maximize_brightness:
		var max_val = maxf(final_r, maxf(final_g, final_b))
		
		if max_val > 0.0:
			# Scale up to max out the brightest channel at 1.0 (255)
			final_r /= max_val
			final_g /= max_val
			final_b /= max_val
		else:
			# If it's pure black, force it to white
			final_r = 1.0
			final_g = 1.0
			final_b = 1.0
	else:
		# Do nothing, keep the standard, unscaled math values
		pass
	# -------------------------------

	return Color(final_r, final_g, final_b, final_a)
	
func get_color_similarity(color1: Color, color2: Color):
	# 1. Calculate the raw differences in channels
	var dr := color1.r - color2.r
	var dg := color1.g - color2.g
	var db := color1.b - color2.b
	
	# 2. Use a weighted Euclidean distance to mimic human eye perception
	# Human eyes see Green best, Red okay, and Blue poorly.
	var distance_squared := (dr * dr * 0.299) + (dg * dg * 0.587) + (db * db * 0.114)
	var distance := sqrt(distance_squared)
	
	# 3. Max possible distance with these weights is 1.0 (Black to White)
	# Turn distance into a percentage (0.0 = identical, 1.0 = completely opposite)
	var similarity := (1.0 - distance) * 100.0
	
	return clampf(similarity, 0.0, 100.0)
	
func get_corner_positions() -> Dictionary:
	# Ensure there is a texture loaded to avoid null errors
	var texture = get_node("Color_Triangle/Triangle").texture

	# Get the base texture size in pixels
	var tex_size = texture.get_size()
	
	# Calculate scaled half-extents (accounting for node scale and mirroring/flip)
	var half_width = (tex_size.x / 2.0) * abs(get_node("Color_Triangle/Triangle").scale.x) * 1.4
	var half_height = (tex_size.y / 2.0) * abs(get_node("Color_Triangle/Triangle").scale.y) * 1.4

	# Calculate all four global positions
	return {
		"top_left": Vector2(-half_width, -half_height),
		"top_right": Vector2(half_width, -half_height),
		"bottom_left": Vector2(-half_width, half_height),
		"bottom_right": Vector2(half_width, half_height)
	}
	
func set_target_on_triangle(current_color: Color):
	var pos_green = (triangle_corners["top_right"] + triangle_corners["top_left"]) / 2
	var pos_red = triangle_corners["bottom_right"] 
	var pos_blue = triangle_corners["bottom_left"] 
	
	# 1. Normalize the color channels so they always sum up to 1.0.
	# This ensures the marker always stays flat on the 2D plane of the triangle,
	# even if the color's brightness varies slightly.
	var total := current_color.r + current_color.g + current_color.b
	
	if total == 0.0:
		# Fallback to the center of the triangle if the color is pure black
		return (pos_red + pos_green + pos_blue) / 3.0
		
	var w_red := current_color.r / total
	var w_green := current_color.g / total
	var w_blue := current_color.b / total
	
	# 2. Use the normalized channels as weights to find the final 2D position
	var marker_pos = (pos_red * w_red) + (pos_green * w_green) + (pos_blue * w_blue)
	
	return marker_pos
	
func setup_Done():
	$UI_Labels/Done.text = "[left][url=\"" + "Next" + "\"]" + "Next" + "[/url][/left]" + "\n"
				
func setup_Dump():
	$UI_Labels/Dump.text = "[left][url=\"" + "Dump" + "\"]" + "Dump" + "[/url][/left]" + "\n"
	
func setup_people():
	for people in [$person1, $person2]:
		people.visible = true
	$person1.position = Vector2(-117, 250)
	$person2.position = Vector2(11700, 250)
	walking = true
	waiting_to_walk = 0


func _on_done_meta_clicked(meta: Variant) -> void:
	mouse_on_color_triangle = false
	if walking == false and thanking == false:
		if blended_fruits != []:
			dump_blender()
		#generate_new_color()
			#waiting_to_walk
		$Request.modulate = Color("#ffffff00")
		$Request_Label.visible = false
		if waiting_to_walk == 0:
			waiting_to_walk = 1
			$person2.position = Vector2(-117, 250)
		else:
			waiting_to_walk = 0
			$person1.position = Vector2(-117, 250)
		walking = true
		generate_new_color()
		$Thanks_Timer.stop()
		thanking = false

func _on_dump_meta_clicked(meta: Variant) -> void:
	mouse_on_color_triangle = false
	if thanking == false:
		dump_blender()
	
func dump_blender():
	start_dumping()
	blend(true)
	blended_fruits = []
	$Blendernolid/BlenderFull.modulate = Color("#ffffff00")
	$UI_Labels/Percent_Correct.text = "0%"
	$UI_Labels/Percent_Correct.visible = false
	$UI_Labels/Blender_Size.text = "0"
	get_node("Color_Triangle/Triangle/Target").position = set_target_on_triangle(Color("#ffffff"))
	
func generate_new_color():
	
	if total_smoothie_count == 0:
		current_size = possible_sizes[0]
	elif total_smoothie_count == 1:
		current_size = possible_sizes[4]
	else:
		current_size = possible_sizes.pick_random()
	total_smoothie_count += 1
	var target_color_list = []
	
	$Request_Label.text = current_size[0] + "\n(" + str(current_size[1]) + " fruit)"
	for i in range(1, current_size[1] + 1):
		target_color_list.append(select_random_fruit_color())
	target_color = average_color_list(target_color_list)
	if target_color == Color("#ffffff"):
		total_smoothie_count -= 1
		generate_new_color()
	else:
		#return(target_color)
		print("secret recipe: " + str(target_color_list))
		$UI_Labels/Points.text = str(total_smoothie_count-1)
		
		if total_smoothie_count == 4:
			_build_fruit_containers(["banana"])
		elif total_smoothie_count == 8:
			_build_fruit_containers(["strawberry"])

func select_random_fruit_color():
	#print(total_smoothie_count)
	if total_smoothie_count >= 8:
		return ((fruit_list.pick_random())[0])
	elif total_smoothie_count >= 4:
		return (([fruit_list[0], fruit_list[1], fruit_list[2], fruit_list[3]].pick_random())[0])
	else:
		return (([fruit_list[0], fruit_list[1], fruit_list[2]].pick_random())[0])


func _on_thanks_timer_timeout() -> void:
	print('w')
	if walking == true and thanking == true and $Thanks_Timer.is_stopped():
		$Thanks_Timer.start()
	elif thanking == true:
		$Thanks_Timer.stop()
		thanking = false
		_on_done_meta_clicked("Next")


func _on_blender_button_mouse_entered() -> void:
	mouse_on_blender_button = true
	ready_to_point_hand = true
	if on_main_menu == false:
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
	
func _on_blender_button_mouse_exited() -> void:
	mouse_on_blender_button = false
	ready_to_point_hand = false
	
	if on_main_menu == false:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func _on_snappy_timer_timeout() -> void:
	if snappyfied == false:
		#print("eh")
		snappyfied = true
		$Request_Label.text = "and make it\nsnappy!"
		$Snappy_Timer.stop()
		$Snappy_Timer.start(1.0)
	else:
		#print("ohh")
		$Request_Label.text = current_size[0] + "\n(" + str(current_size[1]) + " fruit)"


func _on_area_2d_mouse_entered() -> void:
	#if color_triangle_toggled_on == false:
	#	$Color_Triangle.modulate = Color("#ffffff3c")#Color("ffffff78")
	mouse_on_color_triangle = true
	ready_to_point_hand = true
	if on_main_menu == false:
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)

func _on_area_2d_mouse_exited() -> void:
	#if color_triangle_toggled_on == false:
	#	$Color_Triangle.modulate = Color("#ffffff3c")
	mouse_on_color_triangle = false
	ready_to_point_hand = false
	
	if on_main_menu == false:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		
func apply_fonts():
	var wet_font = load("res://assets/Bubbledee_Font.otf")
	var dry_font = load("res://assets/Ngaco_Font.otf")
	
	for nod in $Menu.get_children():
		if nod.name == "Sub_Label2":
			all_text_nodes.append([nod, dry_font])
		else:
			all_text_nodes.append([nod, wet_font])
	for nod in $UI_Labels.get_children():
		all_text_nodes.append([nod, dry_font])
	all_text_nodes.append([$Request_Label, dry_font])
	
	for tex in all_text_nodes:
		tex[0].add_theme_font_override("font", tex[1])
		tex[0].add_theme_font_override("normal_font", tex[1])
