class_name Task
extends Node3D

var thalamus_stub: ThalamusStub = null

signal task_complete(TaskControllerTaskResult)

func apply_config(config: Dictionary) -> void: pass

func get_value(config: Variant) -> float:
	if config is float:
		return config

	var min = config['min'] as float
	var max = config['max'] as float
	var range = abs(max - min)
	return randf()*range + min
