extends Area2D
class_name Pickup

const BLINK_ENABLED_SHADER_PARAMETER: StringName = &"blink_enabled"

@export var config: PickupConfig

@export_range(0.0, 10.0, 0.1, "or_greater") var blink_before_expire: float = 1.2

@onready var spirte: Sprite2D = $Sprite2D
@onready var life_timer: Timer = $LifeTimer

# 闪烁一旦开启就保持到道具消失为止
var is_expired: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	life_timer.timeout.connect(_on_life_timer_timeout)

	life_timer.one_shot = true
	if life_timer.wait_time > 0.0:
		life_timer.start()

	_set_blink_enabled(false)
	_apply_config_to_visual()


# 道具临近消失时闪烁
func _process(_delta: float) -> void:
	if is_expired:
		return

	if life_timer.is_stopped():
		return

	if life_timer.time_left > blink_before_expire:
		return

	is_expired = true
	_set_blink_enabled(true)


func _set_blink_enabled(enabled: bool) -> void:
	var sprite_material = spirte.material as ShaderMaterial
	if sprite_material != null:
		sprite_material.set_shader_parameter(BLINK_ENABLED_SHADER_PARAMETER, enabled)


func _apply_config_to_visual() -> void:
	if config == null:
		push_warning("Pickup Config is null")
		return

	spirte.texture = config.icon


func _on_body_entered(body: Node2D) -> void:
	if config == null:
		return

	var player := body as Player
	if player == null:
		return

	if player.apply_pickup(config):
		queue_free()


func _on_life_timer_timeout() -> void:
	queue_free()
