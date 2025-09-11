extends Node2D

# Player Stats
var health: int = 12
var max_health: int = 12
var bombs: int = 10
var lives: int = 4
var score: int = 0

# Game State
var game_paused: bool = false
var game_over: bool = false
var level: int = 1

# Player References
@onready var player: CharacterBody2D = $Bullwinkle

# UI References
@onready var health_label: Label = %Health
@onready var bombs_label: Label = %Bombs
@onready var lives_label: Label = %Lives
@onready var score_label: Label = %Score

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Initialize game state
	update_ui()
	
	# Connect to player signals if they exist
	if player and player.has_signal("health_changed"):
		player.connect("health_changed", _on_player_health_changed)
	if player and player.has_signal("bomb_used"):
		player.connect("bomb_used", _on_bomb_used)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if not game_paused and not game_over:
		# Game logic can be added here if needed
		pass

# Player Health Functions
func take_damage(amount: int) -> void:
	health = max(0, health - amount)
	update_ui()
	
	if health <= 0:
		_on_player_died()

func heal(amount: int) -> void:
	health = min(max_health, health + amount)
	update_ui()

func _on_player_health_changed(new_health: int) -> void:
	health = new_health
	update_ui()

# Bomb Functions
func use_bomb() -> bool:
	if bombs > 0:
		bombs -= 1
		update_ui()
		return true
	return false

func add_bombs(amount: int) -> void:
	bombs += amount
	update_ui()

func _on_bomb_used() -> void:
	use_bomb()

# Lives Functions
func lose_life() -> void:
	lives -= 1
	update_ui()
	
	if lives <= 0:
		_on_game_over()
	else:
		_respawn_player()

func add_life() -> void:
	lives += 1
	update_ui()

# Score Functions
func add_score(points: int) -> void:
	score += points
	update_ui()

func reset_score() -> void:
	score = 0
	update_ui()

# Game State Functions
func pause_game() -> void:
	game_paused = true
	get_tree().paused = true

func unpause_game() -> void:
	game_paused = false
	get_tree().paused = false

func _on_player_died() -> void:
	lose_life()

func _on_game_over() -> void:
	game_over = true
	# TODO: Show game over screen


func _respawn_player() -> void:
	# Reset player health and position
	health = max_health
	if player:
		# TODO: Reset player position to spawn point
		pass
	update_ui()

# UI Functions
func update_ui() -> void:
	# Update UI labels
	health_label.text = "Health: " + str(health) + "/" + str(max_health)
	bombs_label.text = str(bombs)
	lives_label.text = str(lives)
	score_label.text = "Score: " + str(score)

# Input handling
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if game_paused:
			unpause_game()
		else:
			pause_game()
