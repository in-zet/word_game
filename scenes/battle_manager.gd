class_name BattleManager
extends Node

var player
var enemy


@export var battle_state: Resource

@export var TURNMS_BASE: int = 1000

@onready var display_manager: DisplayManager = %DisplayManager

func battle_init():
	display_manager.display_init()
	


func battle_start(enemy_set):
	enemy = enemy_set


func _on_turn_timer_timeout() -> void:
	pass # Replace with function body.
