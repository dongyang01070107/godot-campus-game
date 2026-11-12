extends Node

var score: int = 0
var notebook_count: int = 0
var time_bonus: int = 0
var won: bool = false


func reset_run() -> void:
	score = 0
	notebook_count = 0
	time_bonus = 0
	won = false


func finish_run(did_win: bool, final_score: int, notebooks: int, bonus: int) -> void:
	won = did_win
	score = final_score
	notebook_count = notebooks
	time_bonus = bonus
