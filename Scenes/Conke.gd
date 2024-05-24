extends Area2D

var speed = 1
var velocity = Vector2(0, 0)
var yugo = null

func _process(delta):
	if yugo == null:
		return
	
	var vector = yugo.global_position - global_position
	vector.normalized()
	velocity = vector * speed * delta
	
	position.x += velocity.x
	position.y += velocity.y

func destroy():
	get_tree().queue_delete(self)

func _on_Conke_body_entered(body):
	if body.is_in_group("Yugo"):
		destroy()
