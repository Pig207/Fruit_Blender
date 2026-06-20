extends AudioStreamPlayer

func _ready():
	# 1. Load your MP3 file (replace with your actual file path)
	stream = load("res://assets/CoffeeShop.mp3")
	
	# 2. Prevent the game from pausing the music when the menu is open
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# 3. Start playing
	play()

func _process(_delta):
	# 4. If the track finishes, play it again loop-style
	if not playing:
		play()
