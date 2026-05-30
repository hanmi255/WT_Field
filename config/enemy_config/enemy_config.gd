extends Resource
class_name EnemyConfig

enum EnemyType {
	BASIC,
    SHELLED,
    FAST_SMALL,
    BOMBER
}

@export_group("基础信息")
@export var enemy_type: EnemyType = EnemyType.BASIC
@export var display_name: String = "基础敌人"

@export_group("基础数值")
# 最大生命值
@export_range(1, 999, 1, "or_greater") var max_health: int = 3
# 移动速度，单位像素/秒
@export_range(0.0, 1000.0, 1.0, "or_greater") var move_speed: float = 60.0
# 圆形碰撞区域半径
@export_range(1.0, 256.0, 0.5, "or_greater") var collision_radius: float = 8.0

@export_group("动画资源")
@export var enemy_frames: SpriteFrames
@export var move_animation_name: StringName = &"move"
@export var death_animation_name: StringName = &"death"
@export var explosion_animation_name: StringName = &"explosion"

@export_group("死亡效果")
@export var explode_on_death: bool = false
# 自爆伤害，只有在explode_on_death为true时才有效
@export_range(0, 999, 1, "or_greater") var explosion_damage: int = 0
# 自爆半径，只有在explode_on_death为true时才有效
@export_range(0.0, 512.0, 1.0, "or_greater") var explosion_radius: float = 0.0

@export_group("掉落物品")
@export_range(0.0, 1.0, 0.01) var pickup_drop_chance: float = 0.3
# 掉落物品配置列表，为空时表示不掉落
@export var pickup_drop_configs: Array[PickupConfig] = [
    preload("res://config/pickup_config/pickup_speed.tres"),
    preload("res://config/pickup_config/pickup_rapid.tres"),
    preload("res://config/pickup_config/pickup_spiral.tres")
]