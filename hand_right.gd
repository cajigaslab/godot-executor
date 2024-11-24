extends Node3D

var credentials = Grpc.InsecureChannelCredentials()
var channel = Grpc.CreateChannel('localhost:50050', credentials)
var stub = Thalamus.NewStub(channel)
var stream: GrpcStream = null
var bones: Dictionary = {}
var skeleton: Skeleton3D = null

func _ready() -> void:
	#Map each xsens joint to a bone
	skeleton = get_node("RootNode/Skeleton3D")
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

func _process(delta: float) -> void:
	pass
	#If the motion capture hasn't been created check if we have a Thalamus
	#connection and start the stream.  Pass each message we receive to
	#_on_message.222

func _on_message(message):
	var rotations = {}
	for segment in message.segments:
		#The coordinate systems used in Unity and Godot are different so we use
		#-q2 and -q3.  This transformation was derived from trial and error.
		
		#Subtract 1 from id when using a hand engine node.  This is a bug in the
		#HAND_ENGINE node  I haven't fixed.
		rotations[segment.id-1] = Quaternion(segment.q1, -segment.q2, -segment.q3, segment.q0)
	
	#The Xsens format published by Thalamus uses global poses but Godot requires
	#local poses relative to the parent joint.  The following code starts from
	#the finger tips and subtracts the orientation of the parent joint working
	#back to the wrist.
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
	
	#Skip the wrist orientation.  Only the fingers should move
	rotations.erase(43)
	for id in rotations:
		var rotation = rotations[id]
		skeleton.set_bone_pose_rotation(bones[id], rotation)
	
