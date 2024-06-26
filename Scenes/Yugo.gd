extends KinematicBody2D

var speed = 150
var velocity = Vector2(0, 0)

func _physics_process(_delta):
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		velocity.x = -speed
		$Sprite.flip_h = false
	elif Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		velocity.x = speed
		$Sprite.flip_h = true
	else:
		velocity.x = 0

	velocity = move_and_slide(velocity, Vector2.UP)
