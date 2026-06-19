class_name Utilities
extends Node

static func play_sfx(sfx_player: AudioStreamPlayer) -> void:
	if sfx_player == null or sfx_player.stream == null:
		return

	sfx_player.stop()
	sfx_player.play()
