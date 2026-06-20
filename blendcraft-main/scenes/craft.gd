# Main.gd
extends Node

var fruits: Dictionary = {
	"cherry": 4,
	"kale": 4,
	"blueberry": 4
}
var in_blender = []
var blended_fruits = []
var maximize_brightness = true #change to false for old mode
var current_blend_color = Color("#ffffff00")
var walking = false
var waiting_to_walk = 0
var possible_sizes = [["Small", 2], ["Small", 2], ["Small", 2], ["Medium", 3], ["Medium", 3], ["Large", 5]]
var fruit_list = [["cherry", "#ff0000"], ["blueberry", "#0000ff"], ["kale", "#00ff00"]]#, ["Strawberry", "#ffa3cb"], ["Banana", "#fff563"], ["Orange", "#ff901d"]]
var target_color
var percentage_similarity = 0
var current_size = ["Large", 5]
var thanking = false
var mouse_on_blender_button = false
var total_smoothie_count = 0
var snappyfied = false

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

func _ready():
	total_smoothie_count = 0
	generate_new_color()
	_build_fruit_containers()
	$Blendernolid/BlenderFull.modulate = Color("#ffffff00")
	$Request.modulate = Color("#ffffff00")
	$Request_Label.visible = false
	setup_Done()
	setup_Dump()
	setup_people()

func _physics_process(delta: float) -> void:
	var speed: float = 3.0
	var bob_speed: float = 12.0     # How fast it steps up and down
	var bob_height: float = 15.0    # How high the bounce goes
	var people = [$person1, $person2]
	if walking == true:
		if people[waiting_to_walk].position.x < 570:
			for p in people:
				p.position.x += speed
				# The Math trick: abs(sin()) creates the hard floor impact and smooth top
				var bounce = abs(sin(p.position.x)) * bob_height
				# Subtract bounce because in 2D, negative Y is UP
				p.position.y = 250 - bounce
		else:
			walking = false
			$Request.modulate = target_color
			$Request_Label.visible = true
			
			if total_smoothie_count == 3 and $Snappy_Timer.is_stopped():
				$Snappy_Timer.start()
			
	if Input.is_action_just_released("click") and mouse_on_blender_button == true:
		start_blending()
		blend()
		
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

# add all the fruits in a given fruit dish to the grid container
func _build_fruit_containers():
	for fruit_name in fruits:
		print(fruit_name)
		print(fruits[fruit_name])
		var container = FruitContainer.instantiate()
		fruit_slot_area.add_child(container)
		container.setup(fruit_name, fruits[fruit_name])

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

func blend():
	
	if thanking == true:
		return
	var fruits = ["cherry", "blueberry", "kale"]
	var goners = []
	for i in in_blender:
		for j in fruits:
			if j in i.name:
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
			$Percent_Correct.text = "%01d" % [percentage_similarity] + "%"
		else:
			$Percent_Correct.text = "%02d" % [percentage_similarity] + "%"
		$Blender_Size.text = str(len(blended_fruits))
		if percentage_similarity == 100.0 and ((len(blended_fruits)) >= current_size[1]) and $Thanks_Timer.is_stopped() == true:
			$Thanks_Timer.start()
			#$Request.modulate = target_color
			thanking = true
			if total_smoothie_count < 3:
				$Request_Label.text = ["Thanks!", "Thank you!", "Perfect!"].pick_random()
			else:
				$Request_Label.text = ["Thanks!", "Thank you!", "About time...", "Perfect!"].pick_random()
				
func average_color_list(blended_fruits):
	var colors = []
	var fruit_list = [["cherry", "#ff0000"], ["blueberry", "#0000ff"], ["kale", "#00ff00"], ["strawberry", "#ffa3cb"], ["banana", "#fff563"], ["orange", "#ff901d"]]
	for i in blended_fruits:
		for j in fruit_list:
			if i == j[0]:
				colors.append(Color(j[1]))
	
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
	
func setup_Done():
	$Done.text = "[left][url=\"" + "Next" + "\"]" + "Next" + "[/url][/left]" + "\n"
				
func setup_Dump():
	$Dump.text = "[left][url=\"" + "Dump" + "\"]" + "Dump" + "[/url][/left]" + "\n"
	
func setup_people():
	for people in [$person1, $person2]:
		people.visible = true
	$person1.position = Vector2(-117, 250)
	#$person2.position = Vector2(-117, 232)
	walking = true
	waiting_to_walk = 0


func _on_done_meta_clicked(meta: Variant) -> void:
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

func _on_dump_meta_clicked(meta: Variant) -> void:
	if thanking == false:
		dump_blender()
	
func dump_blender():
	start_dumping()
	blend()
	blended_fruits = []
	$Blendernolid/BlenderFull.modulate = Color("#ffffff00")
	$Percent_Correct.text = "0%"
	$Blender_Size.text = "0"
	
func generate_new_color():
	if total_smoothie_count == 0:
		current_size = possible_sizes[0]
	elif total_smoothie_count == 1:
		current_size = possible_sizes[4]
	else:
		current_size = possible_sizes.pick_random()
	total_smoothie_count += 1
	var target_color_list = []
	
	$Request_Label.text = current_size[0] + " (" + str(current_size[1]) + " fruit)"
	for i in range(1, current_size[1] + 1):
		target_color_list.append(select_random_fruit_color())
	target_color = average_color_list(target_color_list)
	if target_color == Color("#ffffff"):
		generate_new_color()
		total_smoothie_count -= 1
	#return(target_color)

func select_random_fruit_color():
	return ((fruit_list.pick_random())[0])


func _on_thanks_timer_timeout() -> void:
	thanking = false
	_on_done_meta_clicked("Next")


func _on_blender_button_mouse_entered() -> void:
	mouse_on_blender_button = true
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
	
func _on_blender_button_mouse_exited() -> void:
	mouse_on_blender_button = false
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func _on_snappy_timer_timeout() -> void:
	if snappyfied == false:
		print("eh")
		snappyfied = true
		$Request_Label.text = "and make it\nsnappy!"
		$Snappy_Timer.stop()
		$Snappy_Timer.start(1.0)
	else:
		print("ohh")
		$Request_Label.text = current_size[0] + " (" + str(current_size[1]) + " fruit)"
