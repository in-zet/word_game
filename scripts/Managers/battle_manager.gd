class_name BattleManager
extends Node


@onready var display_manager: DisplayManager = %DisplayManager
@onready var data: Node = %BattleManagerData

func battle_init():
	display_manager.display_init()
	# player init


func battle_start(enemy_set):
	data.enemy = enemy_set
	line_start()


func line_start():
	# line load
	# view update
	pass



func _on_turn_timer_timeout() -> void:
	pass # Replace with function body.
