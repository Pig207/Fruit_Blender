extends Sprite2D

var total_smoothie_count = 0
var speed = 100
var attitude = "default"
var size_preference = "default"
var img_path = ""
var smoothie_position = Vector2.ZERO
var current_size = ["Large", 5]
var possible_sizes = [["Small", 2], ["Small", 2], ["Small", 2], ["Medium", 3], ["Medium", 3], ["Large", 5]]
var default_speed = 300
var target_position = 570
var default_attitude = "default"
var default_size_preference = "default"
var default_img_path = "res://path/to/default/customer_image.png"
var default_smoothie_position = Vector2(50, -30)
var target_color

var fruit_list = [["cherry", "#ff0000"], ["blueberry", "#0000ff"], ["kale", "#00ff00"], ["banana", "#fff563"], ["strawberry", "#ffa3cb"]]#, ["orange", "#ff901d"]]

var customers = {
	"Emmitt": {"speed": "default", "attitude": "default", "size_preference": "default", "img_path": "res://assets/person1.png", "smoothie_position": Vector2(60, -40)},
	"Jeneca": {"speed": "default", "attitude": "default", "size_preference": "default", "img_path": "res://assets/person2.png", "smoothie_position": Vector2(40, -20)},
	"Dean": {"speed": 450, "attitude": "default", "size_preference": "default", "img_path": "res://assets/person3.png", "smoothie_position": Vector2(50, -30)},
	"Gene": {"speed": "default", "attitude": "meh", "size_preference": "default", "img_path": "res://assets/person4.png", "smoothie_position": Vector2(60, -40)},
	"Latte": {"speed": "default", "attitude": "cat", "size_preference": "default", "img_path": "res://assets/person5.png", "smoothie_position": Vector2(40, -20)},
}

var previous_customer = ""
var current_customer = ""
var skipped = false
var walking = true
var thanking = false
var people_bob_height = 10
var received_smoothie = false

@onready var request_label = $Request_Label
@onready var smoothie = $Smoothie
@onready var smoothie_filling = $SmoothieFilling

signal smoothie_received

func _ready():
	# init
	randomize_customer(previous_customer)
	position = Vector2(-117, 232)
	walking = true
	received_smoothie = false
	smoothie.visible = false
	smoothie_filling.visible = false
	$Request.modulate = Color("#ffffff00")
	
	$Request_Label.visible = false
	$Request.visible = false

func _process(delta):
	# walking in
	if walking and not received_smoothie and not skipped:
		if position.x < target_position:
			position.x += speed * delta
			var bounce = abs(sin(position.x * 0.05)) * people_bob_height
			position.y = 250 - bounce
		# in position
		else:
			walking = false
			$Request.modulate = target_color
			$Request_Label.visible = true
			$Request.visible = true
	# walking out with smoothie
	elif received_smoothie:
		if position.x < 1200:
			position.x += speed * delta
			var bounce = abs(sin(position.x * 0.05)) * people_bob_height
			position.y = 250 - bounce
			
		else:
			queue_free() 
	# walking out without smoothie
	elif skipped:
		if position.x < 1200:
			position.x += speed * delta
			var bounce = abs(sin(position.x * 0.05)) * people_bob_height
			position.y = 250 - bounce
			smoothie.position = smoothie_position
			smoothie_filling.position = smoothie_position
		# out of frame
		else:
			queue_free() 
		

func randomize_customer(previous):
	# random new customer
	var available_customers = customers.keys()
	available_customers.erase(previous)
	current_customer = available_customers[randi() % available_customers.size()]
	
	# set customer properties
	if current_customer in customers:
		speed = customers[current_customer].get("speed", default_speed)
		attitude = customers[current_customer].get("attitude", default_attitude)
		size_preference = customers[current_customer].get("size_preference", default_size_preference)
		img_path = customers[current_customer].get("img_path", default_img_path)
		smoothie_position = customers[current_customer].get("smoothie_position", default_smoothie_position)
	else:
		speed = default_speed
		attitude = default_attitude
		size_preference = default_size_preference
		img_path = default_img_path
		smoothie_position = default_smoothie_position
	if str(speed) == "default":
		speed = default_speed
	texture = load(img_path)

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
	target_color = get_parent().average_color_list(target_color_list)
	if target_color == Color("#ffffff"):
		total_smoothie_count -= 1
		generate_new_color()
	else:
		#return(target_color)
		print("secret recipe: " + str(target_color_list))
		
		
		if total_smoothie_count == 4:
			get_parent()._build_fruit_containers(["banana"], true)
		elif total_smoothie_count == 8:
			get_parent()._build_fruit_containers(["strawberry"], true)
		get_parent().target_color = target_color

func select_random_fruit_color():
	#print(total_smoothie_count)
	if total_smoothie_count >= 8:
		return ((fruit_list.pick_random())[0])
	elif total_smoothie_count >= 4:
		return (([fruit_list[0], fruit_list[1], fruit_list[2], fruit_list[3]].pick_random())[0])
	else:
		return (([fruit_list[0], fruit_list[1], fruit_list[2]].pick_random())[0])

var cat_thanks = ['Meow\nYum', 'Thank you\nvery meowch']
var meh_thanks = ['Shit got me\nturning into a\n yum emoji', 'This is\nnot meh']
var default_thanks = ["Thanks!", "Thank you!", "Perfect!"]
var default_thanks_lvl3 = ["Thanks!", "Thank you!", "About time...", "Perfect!"]

func receive_smoothie(smoothie_color):
	if customers[current_customer].get("attitude", "default") == "cat":
		$Request_Label.text = cat_thanks.pick_random()
	elif customers[current_customer].get("attitude", "default") == "meh":
		$Request_Label.text = meh_thanks.pick_random()
	elif total_smoothie_count < 3:
		$Request_Label.text = default_thanks.pick_random()
	else:
		$Request_Label.text = default_thanks_lvl3.pick_random()
	if current_customer == "Dean":
		$Request_Label.text = "Do u know how\nto black out"
	smoothie.visible = true
	smoothie_filling.visible = true
	smoothie_filling.modulate = smoothie_color
	$Request.modulate = smoothie_color
	get_parent().update_balance(current_size[1]*5)
	# wait then walk away
	thanking = true
	await get_tree().create_timer(2.0).timeout
	thanking = false
	
	print('timer ended')
	received_smoothie = true
	walking = true
	emit_signal("smoothie_received")
