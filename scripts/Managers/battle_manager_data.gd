extends Resource

@export var battle_state: Resource

## 한 턴에 걸리는 시간 (ms)
@export var turn_ms_base: int = 1000


var player: Character = null
var enemy: Character = null

var cur_enemy_line = []
