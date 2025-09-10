extends CharacterBody2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

const MAX_SPEED = 300.0
const ACCELERATION = 1200.0
const FRICTION = 1000.0
const JUMP_VELOCITY = -400.0


func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Handle jump animation when airborne
	if not is_on_floor():
		# Flip sprite based on velocity direction when jumping
		animated_sprite.flip_h = velocity.x < 0
		# Play jump animation when in air
		if animated_sprite.animation != "jump":
			animated_sprite.play("jump")
	else:
		# Get the input direction and handle the movement/deceleration.
		# As good practice, you should replace UI actions with custom gameplay actions.
		var direction := Input.get_axis("ui_left", "ui_right")
		if direction:
			# Apply acceleration in the direction of input
			velocity.x = move_toward(velocity.x, direction * MAX_SPEED, ACCELERATION * delta)
			# Flip sprite when moving left
			animated_sprite.flip_h = direction < 0
			# Play run animation when moving
			if animated_sprite.animation != "run":
				animated_sprite.play("run")
		else:
			# Apply friction when no input
			velocity.x = move_toward(velocity.x, 0, FRICTION * delta)
			# Play skid animation when slowing down but still moving
			if abs(velocity.x) > 10:  # Small threshold to avoid jittering
				# Flip sprite based on velocity direction
				animated_sprite.flip_h = velocity.x < 0
				if animated_sprite.animation != "skid":
					animated_sprite.play("skid")
			else:
				# Play idle animation when stopped or nearly stopped
				if animated_sprite.animation != "idle":
					animated_sprite.play("idle")

	move_and_slide()
