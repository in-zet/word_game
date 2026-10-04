class_name BehaveState
extends Node

var target_character: Character
var data_dict: Dictionary[RangeType.Value, BehaveStateData] = {
	RangeType.Value.TEXT: BehaveStateData.new(),
	RangeType.Value.LINE: BehaveStateData.new(),
}


func execute(word: BaseWord):
	if word is Adverb:
		var av_word := word as Adverb
		var target_data := data_dict[av_word.data.modifyRange]
		
		# target_data에 av_word.data랑 더하기 
