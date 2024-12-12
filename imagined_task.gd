extends Task

@export_range(0.0, 1.0) var rock = 1.0
@export_range(0.0, 1.0) var paper = 0.0
@export_range(0.0, 1.0) var scissors = 0.0

enum State {
	INVALID,
	INTER,
	TITLE,
	ANIMATE,
	SUCCESS,
	FAILURE
}

var duration = 0.0
var current_time = 0.0
var audio_filename = ''
var state = State.INVALID
var xsens_stream: ThalamusXsensReactor = null
var inject_stream: ThalamusInjectAnalogReactor = null
var feedback_stream: ThalamusAnalogReactor = null
var feedback_node = ''
var feedback_channel = ''
var transitions = null
var current_pose = ''
var current_transition = 0
var inter_transition_interval = 0.0
var goals = []

@onready var demo_skeleton = $Demo/RootNode/Skeleton3D
@onready var demo_bones = get_bones($Demo/RootNode/Skeleton3D)

var rock_rotations = {43: Quaternion(-0.5101697444915771, 0.7356023192405701, 0.08989693969488144, 0.4365026652812958),
 44: Quaternion(0.02352983132004738, 0.7224982380867004, -0.5469866991043091, 0.42219439148902893),
 45: Quaternion(0.2601701319217682, 0.6638665795326233, -0.376555472612381, 0.591437816619873),
 46: Quaternion(0.47905972599983215, 0.5281184315681458, -0.14185692369937897, 0.686636209487915),
 47: Quaternion(-0.5398920774459839, 0.7264817357063293, 0.040900759398937225, 0.42316415905952454),
 48: Quaternion(-0.011184094473719597, 0.909741222858429, 0.27843400835990906, 0.3077666461467743),
 49: Quaternion(0.6718055605888367, 0.6135401129722595, 0.4150131046772003, -0.003152392106130719),
 50: Quaternion(0.9030243754386902, 0.11091051250696182, 0.3364521563053131, -0.2429933249950409),
 51: Quaternion(-0.5367285013198853, 0.7158949971199036, 0.15434500575065613, 0.41903990507125854),
 52: Quaternion(-0.11144660413265228, 0.8860024213790894, 0.2818608582019806, 0.35090428590774536),
 53: Quaternion(0.5570849180221558, 0.6979090571403503, 0.44804587960243225, 0.04282791167497635),
 54: Quaternion(0.8574671745300293, 0.24934063851833344, 0.3908499479293823, -0.22319422662258148),
 55: Quaternion(-0.5501923561096191, 0.6853684186935425, 0.27182379364967346, 0.39200806617736816),
 56: Quaternion(-0.16915664076805115, 0.8625051379203796, 0.3014480471611023, 0.3695942461490631),
 57: Quaternion(0.551985502243042, 0.6839891672134399, 0.47689270973205566, 0.006648005917668343),
 58: Quaternion(0.8212319612503052, 0.31322067975997925, 0.4154322147369385, -0.2342795580625534),
 59: Quaternion(-0.563012421131134, 0.6342558860778809, 0.38445430994033813, 0.36459749937057495),
 60: Quaternion(-0.1476924568414688, 0.8595940470695496, 0.33250242471694946, 0.35878562927246094),
 61: Quaternion(0.5635523796081543, 0.6656754016876221, 0.48857417702674866, -0.024088667705655098),
 62: Quaternion(0.8562116026878357, 0.16618283092975616, 0.3658679127693176, -0.3246932029724121)}

var paper_rotations = {43: Quaternion(-0.6289121508598328, 0.6772916316986084, -0.04096054285764694, 0.3795626759529114),
 44: Quaternion(-0.2700311839580536, 0.39950302243232727, -0.6496447920799255, 0.5877432823181152),
 45: Quaternion(-0.21507063508033752, 0.4315832555294037, -0.5665897727012634, 0.6681740283966064),
 46: Quaternion(-0.20447233319282532, 0.43670418858528137, -0.5501119494438171, 0.6818044781684875),
 47: Quaternion(-0.6090301871299744, 0.6946605443954468, -0.07769384235143661, 0.3748234510421753),
 48: Quaternion(-0.6175732612609863, 0.7312171459197998, -0.10830235481262207, 0.2686917781829834),
 49: Quaternion(-0.5731475353240967, 0.7665358781814575, -0.09218630194664001, 0.2746386229991913),
 50: Quaternion(-0.560172438621521, 0.776068389415741, -0.08755354583263397, 0.2761504352092743),
 51: Quaternion(-0.6176677346229553, 0.6990918517112732, 0.0442231260240078, 0.3574933111667633),
 52: Quaternion(-0.638857364654541, 0.6688771843910217, -0.048487596213817596, 0.37697944045066833),
 53: Quaternion(-0.5875978469848633, 0.7143278121948242, -0.02045232616364956, 0.3795342445373535),
 54: Quaternion(-0.5875978469848633, 0.7143278121948242, -0.02045232616364956, 0.3795342445373535),
 55: Quaternion(-0.6504523754119873, 0.6709945201873779, 0.14364106953144073, 0.3256458342075348),
 56: Quaternion(-0.6385091543197632, 0.6471831202507019, -0.027735572308301926, 0.41556084156036377),
 57: Quaternion(-0.580411434173584, 0.6997588872909546, 0.00814968254417181, 0.4164056181907654),
 58: Quaternion(-0.568013072013855, 0.7098598480224609, 0.015472863800823689, 0.41619786620140076),
 59: Quaternion(-0.6673150658607483, 0.6370949149131775, 0.2590272128582001, 0.28584203124046326),
 60: Quaternion(-0.6502161026000977, 0.5679407119750977, -0.0028761718422174454, 0.5046326518058777),
 61: Quaternion(-0.6291940808296204, 0.5911449790000916, 0.015424458310008049, 0.5044050216674805),
 62: Quaternion(-0.6248030066490173, 0.5957842469215393, 0.01915612816810608, 0.5042771100997925)}

var scissors_rotations = {43: Quaternion(-0.7347893714904785, 0.5802742838859558, -0.06000720337033272, 0.3460714519023895),
 44: Quaternion(-0.013066262938082218, 0.5122102499008179, -0.5194495320320129, 0.6838435530662537),
 45: Quaternion(0.15037067234516144, 0.4574671685695648, -0.265156626701355, 0.8353469371795654),
 46: Quaternion(0.27127960324287415, 0.39786291122436523, -0.023225797340273857, 0.8761124610900879),
 47: Quaternion(-0.7167884111404419, 0.5960943698883057, -0.09851276874542236, 0.3481108248233795),
 48: Quaternion(-0.7128427028656006, 0.6409807801246643, -0.13961830735206604, 0.24800312519073486),
 49: Quaternion(-0.6477058529853821, 0.7067378163337708, -0.11505082994699478, 0.2603116035461426),
 50: Quaternion(-0.6186999082565308, 0.7322646975517273, -0.10446745157241821, 0.2647364139556885),
 51: Quaternion(-0.7280648946762085, 0.6086699962615967, 0.019083816558122635, 0.31476685404777527),
 52: Quaternion(-0.7302983403205872, 0.5867935419082642, -0.059803154319524765, 0.34461745619773865),
 53: Quaternion(-0.6687107682228088, 0.6561160683631897, -0.0254414863884449, 0.34884142875671387),
 54: Quaternion(-0.6687107682228088, 0.6561160683631897, -0.0254414863884449, 0.34884142875671387),
 55: Quaternion(-0.7617608904838562, 0.5822726488113403, 0.11821146309375763, 0.25827303528785706),
 56: Quaternion(-0.49489638209342957, 0.769184947013855, 0.12537547945976257, 0.384334534406662),
 57: Quaternion(0.19898425042629242, 0.8927335739135742, 0.3614453673362732, 0.18107815086841583),
 58: Quaternion(0.45281070470809937, 0.7946889400482178, 0.3987215757369995, 0.06673187017440796),
 59: Quaternion(-0.7707776427268982, 0.5588442087173462, 0.2382678985595703, 0.191894069314003),
 60: Quaternion(-0.4872823655605316, 0.7816095948219299, 0.1403254270553589, 0.3632506728172302),
 61: Quaternion(0.28552863001823425, 0.875688910484314, 0.3684656023979187, 0.12599752843379974),
 62: Quaternion(0.5241822004318237, 0.7573577165603638, 0.389112651348114, 0.015284978784620762)}

@onready var last_rotations = rock_rotations
@onready var goal_rotations = rock_rotations

func global_to_local_rotations(rotations: Dictionary) -> void:
	rotations[46] = rotations[45].inverse()*rotations[46]
	rotations[45] = rotations[44].inverse()*rotations[45]
	rotations[44] = rotations[43].inverse()*rotations[44]
	
	rotations[50] = rotations[49].inverse()*rotations[50]
	rotations[49] = rotations[48].inverse()*rotations[49]
	rotations[48] = rotations[47].inverse()*rotations[48]
	rotations[47] = rotations[43].inverse()*rotations[47]
	
	rotations[54] = rotations[53].inverse()*rotations[54]
	rotations[53] = rotations[52].inverse()*rotations[53]
	rotations[52] = rotations[51].inverse()*rotations[52]
	rotations[51] = rotations[43].inverse()*rotations[51]
	
	rotations[58] = rotations[57].inverse()*rotations[58]
	rotations[57] = rotations[56].inverse()*rotations[57]
	rotations[56] = rotations[55].inverse()*rotations[56]
	rotations[55] = rotations[43].inverse()*rotations[55]
	
	rotations[62] = rotations[61].inverse()*rotations[62]
	rotations[61] = rotations[60].inverse()*rotations[61]
	rotations[60] = rotations[59].inverse()*rotations[60]
	rotations[59] = rotations[43].inverse()*rotations[59]

func _init() -> void:
	global_to_local_rotations(rock_rotations)
	global_to_local_rotations(paper_rotations)
	global_to_local_rotations(scissors_rotations)

func _process(delta: float) -> void:
	if Input.is_action_pressed("ui_accept"):
		var transition = transitions[current_transition]
		var goal = transition['Goal']
		if current_pose.to_lower().strip_edges() == goal.to_lower().strip_edges():
			transition(State.SUCCESS)
		else:
			transition(State.FAILURE)
		
	current_time += delta
	current_time = min(current_time, duration)
	if xsens_stream == null:
		var selector = ThalamusNodeSelector.new()
		selector.type = "XSENS"
		xsens_stream = thalamus_stub.xsens(selector)
		xsens_stream.connect("received", on_xsens)
		
	var total = rock + paper + scissors
	if total <= 0.0:
		return
	
	for key in rock_rotations:
		if key == 43:
			continue
		var up = 0.0
		var down = 0.0
		if key <= 54:
			up = paper + scissors
			down = rock
		else:
			up = paper
			down = rock + scissors
			
		var last_rotation: Quaternion = last_rotations[key]
		var goal_rotation: Quaternion = goal_rotations[key]
		var demo_rotation = last_rotation.slerp(goal_rotation, current_time/duration)
		
		var demo_bone = demo_bones[key]
		demo_skeleton.set_bone_pose_rotation(demo_bone, demo_rotation)
	
func on_xsens(message: ThalamusXsensResponse):
	current_pose = message.pose_name
	
func apply_config(config: Dictionary) -> void:
	state = State.INVALID
	goal_rotations = rock_rotations
		
	transitions = config['Transitions']
	current_transition = 0
	inter_transition_interval = get_value(config['inter_transition_interval'])
	
	audio_filename = config['audio_file']
	$AudioStreamPlayer.stream = AudioStreamOggVorbis.load_from_file(audio_filename)

	transition(State.INTER)
	
func transition(new_state: State) -> void:
	if new_state == State.INTER:
		$Label.visible = false
		$Demo.visible = false
		$Timer.wait_time = inter_transition_interval
		$Timer.start()
	elif new_state == State.TITLE:
		var transition = transitions[current_transition]
		$AudioStreamPlayer.play()
		$Label.visible = true
		$Demo.visible = false
		$Label.text = transition['Goal']
		$Label.add_theme_color_override("font_color", Color(1, 1, 1))
		$Timer.wait_time = 1
		$Timer.start()
	elif new_state == State.ANIMATE:
		last_rotations = goal_rotations
		$Label.visible = false
		$Demo.visible = true
		var transition = transitions[current_transition]
		var goal = transition['Goal']
		if goal.to_lower().strip_edges() == 'rock':
			goal_rotations = rock_rotations
		elif goal.to_lower().strip_edges() == 'paper':
			goal_rotations = paper_rotations
		else:
			goal_rotations = scissors_rotations
		duration = transition['Duration']
		current_time = 0.0
	elif new_state == State.SUCCESS:
		$Label.visible = true
		$Demo.visible = false
		$Label.text = 'Success'
		$Label.add_theme_color_override("font_color", Color(0, 1, 0))
		$Timer.wait_time = 1
		$Timer.start()
	elif new_state == State.FAILURE:
		$Label.visible = true
		$Demo.visible = false
		$Label.text = 'Failure'
		$Label.add_theme_color_override("font_color", Color(1, 0, 0))
		$Timer.wait_time = 1
		$Timer.start()
	state = new_state

func _on_timeout() -> void:
	print('timeout')
	if state == State.INTER:
		transition(State.TITLE)
	elif state == State.TITLE:
		transition(State.ANIMATE)
	elif state == State.SUCCESS or state == State.FAILURE:
		current_transition += 1
		if current_transition == transitions.size():
			on_finish()
		else:
			transition(State.INTER)
	
func on_finish() -> void:
	var result = TaskControllerTaskResult.new()
	result.success = true
	task_complete.emit(result)
	
func get_bones(skeleton: Skeleton3D) -> Dictionary:
	var bones = {}
	bones[43] = skeleton.find_bone('hand_r')
	bones[44] = skeleton.find_bone('thumb_01_r')
	bones[45] = skeleton.find_bone('thumb_02_r')
	bones[46] = skeleton.find_bone('thumb_03_r')
	
	bones[47] = skeleton.find_bone('index_00_r')
	bones[48] = skeleton.find_bone('index_01_r')
	bones[49] = skeleton.find_bone('index_02_r')
	bones[50] = skeleton.find_bone('index_03_r')
	
	bones[51] = skeleton.find_bone('middle_00_r')
	bones[52] = skeleton.find_bone('middle_01_r')
	bones[53] = skeleton.find_bone('middle_02_r')
	bones[54] = skeleton.find_bone('middle_03_r')
	
	bones[55] = skeleton.find_bone('ring_00_r')
	bones[56] = skeleton.find_bone('ring_01_r')
	bones[57] = skeleton.find_bone('ring_02_r')
	bones[58] = skeleton.find_bone('ring_03_r')
	
	bones[59] = skeleton.find_bone('pinky_00_r')
	bones[60] = skeleton.find_bone('pinky_01_r')
	bones[61] = skeleton.find_bone('pinky_02_r')
	bones[62] = skeleton.find_bone('pinky_03_r')
	return bones
	
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Timer.connect("timeout", _on_timeout)

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
