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
var possible_sizes = [["Small", 2], ["Small", 2], ["Medium", 3], ["Small", 2], ["Medium", 3], ["Large", 5]]
var fruit_list = [["cherry", "#ff0000"], ["blueberry", "#0000ff"], ["kale", "#00ff00"]]#, ["Strawberry", "#ffa3cb"], ["Banana", "#fff563"], ["Orange", "#ff901d"]]
var target_color
var percentage_similarity = 0
var current_size = ["Large", 5]
var thanking = false

@onready var fruit_slot_area = $GridOfContainers  # your HBoxContainer

const FruitContainer = preload("res://scenes/fruit_container.tscn")

func _ready():
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

func _on_button_pressed() -> void:
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
		$Percent_Correct.text = "%02d" % [percentage_similarity] + "%"
		$Blender_Size.text = str(len(blended_fruits))
		if percentage_similarity == 100.0 and ((len(blended_fruits)) == current_size[1]) and $Thanks_Timer.is_stopped() == true:
			$Thanks_Timer.start()
			#$Request.modulate = target_color
			thanking = true
			$Request_Label.text = ["Thanks!", "Thank you!", "About time...", "Perfect!"].pick_random()
		
func average_color_list(blended_fruits):
	var colors = []
	var fruit_list = [["cherry", "#ff0000"], ["blueberry", "#0000ff"], ["kale", "#00ff00"], ["Strawberry", "#ffa3cb"], ["Banana", "#fff563"], ["Orange", "#ff901d"]]
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
	$person1.position = Vector2(-117, 250)
	#$person2.position = Vector2(-117, 232)
	walking = true
	waiting_to_walk = 0


func _on_done_meta_clicked(meta: Variant) -> void:
	if walking == false and thanking == false:
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
	_on_button_pressed()
	blended_fruits = []
	$Blendernolid/BlenderFull.modulate = Color("#ffffff00")
	$Percent_Correct.text = "0%"
	$Blender_Size.text = "0"
	
func generate_new_color():
	current_size = possible_sizes.pick_random()
	var target_color_list = []
	$Request_Label.text = current_size[0] + " (" + str(current_size[1]) + " fruit)"
	for i in range(1, current_size[1] + 1):
		target_color_list.append(select_random_fruit_color())
	target_color = average_color_list(target_color_list)
	if target_color == Color("#ffffff"):
		generate_new_color()
	#return(target_color)

func select_random_fruit_color():
	return ((fruit_list.pick_random())[0])


func _on_thanks_timer_timeout() -> void:
	thanking = false
	_on_done_meta_clicked("Next")
