extends Node2D

var fruit_list = [["Cherry", "#ff0000"], ["Blueberry", "#0000ff"], ["Kale", "#00ff00"], ["Strawberry", "#ffa3cb"], ["Lemon", "#fff526"]]
var target_color 
var color_list = []
var possible_sizes = [["small", 2], ["small", 2], ["Medium", 3], ["small", 2], ["Medium", 3], ["Large", 5]]
var blender_size = 0
var percentage_similarity = 0
var triangle_corners

var maximize_brightness = true #change to false for old mode

func _ready():
	setup_Fruit_List()
	setup_Done()
	setup_Dump()
	generate_new_color()
	triangle_corners = get_corner_positions()
	print(triangle_corners)
	get_node("Color Triangle/Target").position = set_target_on_triangle($Blender/ColorRect.color)
	
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
	get_node("Color Triangle/Target").position = set_target_on_triangle(Color("#ffffff"))
		
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
	get_node("Color Triangle/Target").position = set_target_on_triangle(new_blender_combo)
	
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
	var texture = get_node("Color Triangle/Triangle").texture
	if not texture:
		print("woop")
		return {}

	# Get the base texture size in pixels
	var tex_size = texture.get_size()
	
	# Calculate scaled half-extents (accounting for node scale and mirroring/flip)
	var half_width = (tex_size.x / 2.0) * abs(get_node("Color Triangle/Triangle").scale.x)
	var half_height = (tex_size.y / 2.0) * abs(get_node("Color Triangle/Triangle").scale.y)

	# Calculate all four global positions
	return {
		"top_left": position + Vector2(-half_width, -half_height),
		"top_right": position + Vector2(half_width, -half_height),
		"bottom_left": position + Vector2(-half_width, half_height),
		"bottom_right": position + Vector2(half_width, half_height)
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

func _on_done_meta_clicked(meta: Variant) -> void:
	dump_blender()
	generate_new_color()


func _on_dump_meta_clicked(meta: Variant) -> void:
	dump_blender()
