extends Node2D

var fruit_list = [["Cherry", "#ff0000"], ["Blueberry", "#0000ff"], ["Kale", "#00ff00"], ["Strawberry", "#ffa3cb"], ["Lemon", "#fff526"]]
var target_color 
var color_list = []
var possible_sizes = [["small", 2], ["small", 2], ["Medium", 3], ["small", 2], ["Medium", 3], ["Large", 5]]
var blender_size = 0
var percentage_similarity = 0

func _ready():
	setup_Fruit_List()
	setup_Done()
	setup_Dump()
	generate_new_color()
	
func setup_Fruit_List():
	var text_string = ""
	for i in fruit_list:
		text_string += "[left][color=" + Color(i[1]).to_html() + "][url=\"" + i[1] + "\"]" + i[0] + "[/url][/color][/left]" + "\n"
	$"Fruit Selection/Fruit List".text = text_string
	
func setup_Done():
	$Done.text = "[left][url=\"" + "Done" + "\"]" + "Done" + "[/url][/left]" + "\n"
	
func setup_Dump():
	$Blender/Dump.text = "[left][url=\"" + "Dump" + "\"]" + "Dump" + "[/url][/left]" + "\n"
	
func generate_new_color():
	var current_size = possible_sizes.pick_random()
	var target_color_list = []
	$Size.text = current_size[0] + " (" + str(current_size[1]) + " fruit)"
	for i in range(1, current_size[1] + 1):
		target_color_list.append(select_random_fruit_color())
	target_color = average_color_list(target_color_list)
	$"Order Image/ColorRect".color = target_color
	
func dump_blender():
	percentage_similarity = 0
	$Percentage.text = "0%"
	color_list = []
	$Blender/ColorRect.color = Color("#ffffff")
	blender_size = 0
		
func select_random_fruit_color():
	return Color((fruit_list.pick_random())[1])

func _on_fruit_list_meta_clicked(meta: Variant) -> void:
	color_list.append(Color(meta))
	var new_blender_combo = average_color_list(color_list)
	percentage_similarity = (get_color_similarity(new_blender_combo, target_color))
	$Percentage.text = "%02d" % [percentage_similarity] + "%"
	$Blender/ColorRect.color = new_blender_combo
	blender_size += 1
	$Blender/Blender_Size.text = str(blender_size)

func average_color_list(colors):
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
	return Color(
		sqrt(total_r / count),
		sqrt(total_g / count),
		sqrt(total_b / count),
		total_a / count
	)
	

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

func _on_done_meta_clicked(meta: Variant) -> void:
	dump_blender()
	generate_new_color()


func _on_dump_meta_clicked(meta: Variant) -> void:
	dump_blender()
