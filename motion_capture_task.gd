extends Task

enum State {
  BLANK,
  QUEUE,
  SUCCESS,
  FAILURE
}

var is_first_ready = true
var time_per_symbol = 0.0
var num_iterations = 0
var audio_lead = 0.0
var always_randomize = false
var start_audio_filename = ''
var success_audio_filename = ''
var fail_audio_filename = ''
var indicate_success_failure = false
var blank_time = .032
var LAST_IMAGE = null
var maybe_images: Array[ImageTexture] = []
var maybe_poses = null
var valid_indexes = null
var images = null
var state = State.BLANK
var iteration = 0
var index = 0
var xsens_stream: ThalamusXsensReactor = null
var inject_stream: ThalamusInjectAnalogReactor = null
var current_pose = ""

func on_xsens(message: ThalamusXsensResponse) -> void:
	current_pose = message.pose_name

func apply_config(config: Dictionary) -> void:
	if xsens_stream == null:
		var selector = ThalamusNodeSelector.new()
		selector.type = "XSENS"
		xsens_stream = thalamus_stub.xsens(selector)
		xsens_stream.connect("received", on_xsens)
		inject_stream = thalamus_stub.inject_analog()
		var inject_message = ThalamusInjectAnalogRequest.new()
		inject_message.node = 'gesture_signal'
		inject_stream.write(inject_message)
		
	time_per_symbol = get_value(config['time_per_symbol'])
	num_iterations = int(config['num_iterations'])
	audio_lead = get_value(config['audio_lead'])/1000
	always_randomize = config['always_randomize']
	start_audio_filename = config['start_audio_file']
	success_audio_filename = config['success_audio_file']
	fail_audio_filename = config['fail_audio_file']
	indicate_success_failure = config['indicate_success_failure']
	print('success_audio_filename ', success_audio_filename)
	
	$SuccessPlayer.stream = AudioStreamOggVorbis.load_from_file(success_audio_filename)
	$FailurePlayer.stream = AudioStreamOggVorbis.load_from_file(fail_audio_filename)
	$StartPlayer.stream = AudioStreamOggVorbis.load_from_file(start_audio_filename)

	if always_randomize:
		var available_images = config['available_images']
		var num_random = int(config['num_random'])
		var count = min(num_random, len(available_images))
		var choices = []
		for i in range(count):
			var selected = LAST_IMAGE
			while selected == LAST_IMAGE:
				i = randi() % available_images.size()
				selected = available_images[i]
			choices.append(selected)
			LAST_IMAGE = selected
		config['selected_images'] = choices

	maybe_images = []
	for p in config['selected_images']:
		var image = Image.load_from_file(p[0])
		var texture = ImageTexture.create_from_image(image)
		maybe_images.append(texture)

	maybe_poses = []
	for p in config['selected_images']:
		maybe_poses.append(p[1])

	valid_indexes = []
	for i in range(maybe_images.size()):
		if maybe_images[i] != null:
			valid_indexes.append(i)

	images = []
	for i in range(maybe_images.size()):
		if maybe_images[i] != null:
			images.append(i)
  
	iteration = 0
	index = 0
	transition(State.BLANK)
	
func transition(new_state: State) -> void:
	if new_state == State.BLANK:
		$StartPlayer.play()
		$Label.visible = false
		$TextureRect.visible = false
		$Timer.wait_time = blank_time
		$Timer.start()
	elif new_state == State.QUEUE:
		var valid_index = valid_indexes[index]
		var image = maybe_images[valid_index]
		$TextureRect.texture = image
		$Label.visible = false
		$TextureRect.visible = true
		
		var span = ThalamusSpan.new()
		span.begin = 0
		span.end = 1
		
		var sig = ThalamusAnalogResponse.new()
		sig.spans = [span]
		sig.sample_intervals = [0]
		
		var injection = ThalamusInjectAnalogRequest.new()
		
		sig.data = [5]
		injection.signal = sig
		inject_stream.write(injection)
		
		$InjectTimer.start()
		
	elif new_state == State.SUCCESS:
		$SuccessPlayer.play()
		$TextureRect.visible = false
		$Label.visible = true
		$Label.add_theme_color_override("font_color", Color(0, 1, 0))
		$Label.text = "Success"
		$Timer.wait_time = 1
		$Timer.start()
	elif new_state == State.FAILURE:
		$FailurePlayer.play()
		$TextureRect.visible = false
		$Label.visible = true
		$Label.add_theme_color_override("font_color", Color(1, 0, 0))
		$Label.text = "Failure"
		$Timer.wait_time = 1
		$Timer.start()
	state = new_state

func _on_timeout() -> void:
	print('timeout')
	if state == State.BLANK:
		transition(State.QUEUE)
	elif state == State.SUCCESS or state == State.FAILURE:
		index += 1
		if index >= valid_indexes.size():
			iteration += 1
			index = 0
		if iteration >= num_iterations:
			on_finish()
			return
		transition(State.BLANK)
	
func on_finish() -> void:
	var result = TaskControllerTaskResult.new()
	result.success = true
	task_complete.emit(result)
	
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Timer.connect("timeout", _on_timeout)
	$InjectTimer.connect("timeout", on_inject_timeout)

func on_inject_timeout() -> void:
	var span = ThalamusSpan.new()
	span.begin = 0
	span.end = 1
		
	var sig = ThalamusAnalogResponse.new()
	sig.spans = [span]
	sig.sample_intervals = [0]
		
	var injection = ThalamusInjectAnalogRequest.new()
		
	sig.data = [0]
	injection.signal = sig
	inject_stream.write(injection)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if state == State.QUEUE:
		if Input.is_action_pressed("ui_accept"):
			if current_pose == maybe_poses[index]:
				transition(State.SUCCESS)
			else:
				transition(State.FAILURE)
