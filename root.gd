extends Node

var credentials = Grpc.InsecureChannelCredentials()
var task_controller_channel = Grpc.CreateChannel('localhost:50051', credentials)
var task_controller_stub = TaskController.NewStub(task_controller_channel)
var execution_stream = null
var task_nodes: Array[Task] = []
var current_task_node: Task = null

var thalamus_channel = Grpc.CreateChannel('localhost:50050', credentials)
var thalamus_stub = Thalamus.NewStub(thalamus_channel)


func resize() -> void:
	%OperatorView.content_scale_size = Vector2i(get_window().size)
	get_viewport().size = get_window().size
	
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	get_tree().get_root().size_changed.connect(resize) 
	resize()
	#%OperatorView.world_2d = get_window().world_2d
	get_window().canvas_cull_mask = 1
	
	$InitErrorTimer.connect("timeout", _on_init_error_timeout)
	for child in get_children():
		print(child.name)
		if child is Task:
			child.thalamus_stub = thalamus_stub
			if child.name == 'imagined_task':
				continue
			task_nodes.append(child)
	
	for node in task_nodes:
		remove_child(node)
		node.connect("task_complete", _on_task_complete)
		
	var config = TaskControllerTaskConfig.new()
	config.body = '{ "task_type": "motion_capture_task", "type": "task", "goal": 8, "name": "Untitled", "intertrial_timeout": { "min": 1, "max": 1 }, "start_timeout": { "min": 1, "max": 1 }, "hold_timeout": { "min": 1, "max": 1 }, "blink_timeout": { "min": 1, "max": 1 }, "fail_timeout": { "min": 1, "max": 1 }, "success_timeout": { "min": 1, "max": 1 }, "target_x": { "min": 1, "max": 1 }, "target_y": { "min": 1, "max": 1 }, "target_width": { "min": 1, "max": 1 }, "target_height": { "min": 1, "max": 1 }, "target_color": [255, 255, 255], "targets": [], "available_images": [["C:/Thalamus/board0.png", "board0.png"], ["C:/Thalamus/board1.png", "board1.png"], ["C:/Thalamus/board2.png", "board2.png"]], "selected_images": [["C:/Thalamus/board0.png", "board0.png"], ["C:/Thalamus/board2.png", "board2.png"], ["C:/Thalamus/board1.png", "board1.png"]], "time_per_symbol": 1, "num_iterations": 2, "always_randomize": false, "num_random": 3, "audio_lead": { "min": 1000, "max": 1500 }, "start_audio_file": "C:/Thalamus/success_clip.ogg", "success_audio_file": "", "fail_audio_file": "", "indicate_success_failure": true, "task_cluster_name": "Untitled", "queue_index": 0 }'
	#_on_received(config)

func _on_task_complete(result: TaskControllerTaskResult) -> void:
	remove_child(current_task_node)
	current_task_node = null
	execution_stream.write(result)

func _on_init_error_timeout() -> void:
	if execution_stream == null:
		return
	var result = TaskControllerTaskResult.new()
	result.success = false
	execution_stream.write(result)
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Input.is_action_just_pressed("toggle_fullscreen"):
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	if thalamus_channel.GetState(true) != GrpcConnectivityState.GRPC_CHANNEL_READY:
		return
	
	if execution_stream == null:
		if task_controller_channel.GetState(true) == GrpcConnectivityState.GRPC_CHANNEL_READY:
			print('connected')
			execution_stream = task_controller_stub.execution()
			execution_stream.connect("received", _on_received)
			print('streaming')
		

func _on_received(message: TaskControllerTaskConfig) -> void:
	print('_on_received')
	print(message.body)
	var json = JSON.new()
	var error = json.parse(message.body)
	if error != OK:
		$InitErrorTimer.start()
		return
		
	print(json.data)
	print(json.data.task_type)
	for c in get_children():
		print(c.name)
		
	current_task_node = null
	for node in task_nodes:
		if node.name == json.data.task_type:
			current_task_node = node
			break
			
	if current_task_node == null:
		print('task node not found')
		$InitErrorTimer.start()
		return
			
	add_child(current_task_node)
	current_task_node.apply_config(json.data)
