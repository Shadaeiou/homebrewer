extends Node

## Main controller per DESIGN.md 7.2.
##
## Hosts the persistent scene graph:
##   Main (this node)
##   ├── BackgroundLayer (CanvasLayer, layer=0)
##   │   └── Dashboard (instanced here on _ready)
##   ├── ActiveSceneContainer (Node)
##   ├── PhoneLayer (CanvasLayer, layer=50)
##   ├── ModalLayer (CanvasLayer, layer=100)
##   └── BootSequence (Node)
##
## Mini-game scenes mount under ActiveSceneContainer; Phone + Modal layers
## pause gameplay when shown via PROCESS_MODE_DISABLED propagation.

const DASHBOARD_SCENE := preload("res://scenes/dashboard.tscn")

@onready var background_layer: CanvasLayer = $BackgroundLayer
@onready var active_scene_container: CanvasLayer = $ActiveSceneContainer
@onready var phone_layer: CanvasLayer = $PhoneLayer
@onready var modal_layer: CanvasLayer = $ModalLayer

var _dashboard: Node = null

func _ready() -> void:
	# Mount the persistent dashboard. This is BackgroundLayer's only child;
	# active scenes render on top of it via ActiveSceneContainer.
	_dashboard = DASHBOARD_SCENE.instantiate()
	background_layer.add_child(_dashboard)

	# Phone + Modal layers start empty. They're owned by Main; specific
	# UI flows add/remove children as needed and toggle get_tree().paused.

func mount_active_scene(scene: PackedScene, configure: Callable = Callable()) -> Node:
	## Helper for the brew flow: instantiates `scene`, runs the optional
	## `configure(instance)` callable so callers can set fields BEFORE
	## the node enters the tree (so its _ready sees them), then adds it
	## under ActiveSceneContainer and starts the scene clock.
	clear_active_scene()
	var instance: Node = scene.instantiate()
	if configure.is_valid():
		configure.call(instance)
	active_scene_container.add_child(instance)
	TimeService.start_scene()
	return instance

func clear_active_scene() -> void:
	for child in active_scene_container.get_children():
		child.queue_free()
	if TimeService.is_scene_running():
		TimeService.end_scene()

func push_modal(scene: PackedScene, configure: Callable = Callable()) -> Node:
	## Push a modal onto ModalLayer per 7.2. Pauses the rest of the scene
	## tree so brewing-day timers / scene_clock don't keep running while
	## the modal is up. The modal's root must use PROCESS_MODE_ALWAYS so
	## its own input handlers still fire.
	var instance: Node = scene.instantiate()
	if configure.is_valid():
		configure.call(instance)
	modal_layer.add_child(instance)
	get_tree().paused = true
	return instance

func pop_modal() -> void:
	for child in modal_layer.get_children():
		child.queue_free()
	get_tree().paused = false
