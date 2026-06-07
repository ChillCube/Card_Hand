@icon("res://addons/Card_Hand/icon_hand.png")
extends NodeArranger
class_name CardHand

var orig_distance_horizontal = distance_horizontal

func _init() -> void:
	# Arrangement Settings
	max_vertical = 1
	max_horizontal = 10
	centered = true
	distance_horizontal = 80.0 
	orig_distance_horizontal = distance_horizontal;
	distance_vertical = 0.0
	curve_intensity = 35.0 
	rotation_intensity = 5.0
	offset = Vector2(0, -50)

@export var grid : Grid; ## Optional Grid reference used by cards in this hand for snap-to-grid placement

@export_group("Camera Zoom Adaptation")
@export var adapt_to_camera_zoom: bool = true ## If true and parented to a Camera2D, automatically adjusts scale and position to stay fixed on screen

var _screen_offset: Vector2
var _screen_anchor_x: float
var _bottom_margin: float
var _camera: Camera2D
var _zoom_factor: Vector2 = Vector2.ONE

@export_group("gameplay rules")
@export var max_cards_to_place_per_turn : int = 1; ## makes it so you can't draw more than this amount of cards until the variable "cards_placed_this_turn" is reset
var cards_placed_this_turn = 0;

@export_group("Toggles")
## Toggle the curved "Fan" layout entirely
@export var use_fan_curve : bool = true
## If true, the curve's peak follows the mouse. If false, it stays centered.
@export var dynamic_fan_curve : bool = true
## Toggle the card lifting/popping up when hovered
@export var use_hover_lift : bool = true
## Toggle cards pushing away from the hovered card
@export var use_horizontal_spread : bool = true
## Toggle if the hovered card moves to the front (Z-index)
@export var use_z_index_hover : bool = true

@export_group("Mouse Adaptation")
@export var mouse_reactive : bool = true ## If true, cards respond to mouse proximity with lift and spread effects
@export var reaction_radius : float = 300.0 ## Distance in pixels from the hand center within which mouse proximity effects are active
@export var mouse_lift_height : float = -50.0 ## Y offset applied to the hovered card (negative = upward lift)
@export var horizontal_spread : float = 20.0 ## Horizontal distance in pixels that neighboring cards push away from the hovered card

@export_group("Z-Index Control")
@export var base_z_index : int = 0 ## Z-index assigned to the leftmost card; each subsequent card increments by 1
@export var max_z_bonus : int = 10 ## Extra Z-index added to the hovered card so it renders on top

signal card_added(card: Node2D) ## Emitted when a card node is added to the hand
signal card_removed(card: Node2D) ## Emitted when a card node is removed from the hand
signal card_hovered(card: Node2D) ## Emitted when the mouse begins hovering over a specific card
signal card_hover_ended ## Emitted when the mouse stops hovering over any card in the hand

var _prev_hovered_idx: int = -1

func _ready() -> void:
	child_entered_tree.connect(_on_card_entered)
	child_exiting_tree.connect(_on_card_exiting)
	_cache_camera_and_anchor()

func _cache_camera_and_anchor() -> void:
	if not adapt_to_camera_zoom:
		return
	var p = get_parent()
	if not p is Camera2D:
		return
	_camera = p as Camera2D
	_screen_offset = position * _camera.zoom
	var vp_size := get_viewport_rect().size
	if vp_size != Vector2.ZERO:
		_screen_anchor_x = _screen_offset.x / vp_size.x
		_bottom_margin = vp_size.y / 2.0 - _screen_offset.y
	get_tree().get_root().size_changed.connect(_on_window_resized)

func _on_window_resized() -> void:
	if not _camera:
		return
	var vp_size := get_viewport_rect().size
	if vp_size != Vector2.ZERO:
		_screen_offset.x = vp_size.x * _screen_anchor_x
		_screen_offset.y = vp_size.y / 2.0 - _bottom_margin


func _adapt_to_camera_zoom() -> void:
	if not adapt_to_camera_zoom or not _camera:
		return
	var z := _camera.zoom
	position = _screen_offset / z
	scale = Vector2(4 / z.x, 4.0 / z.y)
	_zoom_factor = z

func _on_card_entered(node: Node) -> void:
	if node is Node2D:
		card_added.emit(node as Node2D)

func _on_card_exiting(node: Node) -> void:
	if node is Node2D:
		card_removed.emit(node as Node2D)

var prev_child_amount = 0;
func _process(_delta: float) -> void:
	_adapt_to_camera_zoom()
	if continous_arranging:
		arrange()
	if get_child_count() != prev_child_amount:
		_update_draggable()
	prev_child_amount = get_child_count();

var connected_cards :Array[Card2D] = []
func _update_draggable():
	var cards = get_children();
	if max_cards_to_place_per_turn <= cards_placed_this_turn:
		for card : Card2D in cards:
			if card.is_draggable:
				card.is_draggable = false;
	else:
		for card : Card2D in cards:
			if card.is_draggable:
				card.is_draggable = true;
	for card : Card2D in cards:
		if card not in connected_cards:
			card.connect("object_placed", _card_placed.bind(card))
			connected_cards.append(card)

func _card_placed(card: Card2D):
	if card.get_parent() != self:
		cards_placed_this_turn += 1
	_update_draggable();

func _arrange_nodes(nodes : Array[Node]) -> void: ## Lays out all cards in a normalized fan arc with optional hover lift, spread, and z-index boost
	var total_to_show = min(nodes.size(), max_horizontal * max_vertical)
	if total_to_show <= 0: return

	var zoom_scale := scale if (adapt_to_camera_zoom and _camera) else Vector2.ONE
	var eff_dist_h := distance_horizontal * zoom_scale.x
	var eff_spread := horizontal_spread * zoom_scale.x
	var eff_lift := mouse_lift_height * zoom_scale.y
	var eff_radius := reaction_radius * zoom_scale.y
	var eff_offset := Vector2(offset.x * zoom_scale.x, offset.y * zoom_scale.y)

	var mouse_pos = get_global_mouse_position()
	var default_center = (total_to_show - 1) / 2.0

	# --- NEW: Intensity Normalization ---
	# We calculate a factor so that the furthest card is always at a fixed Y offset.
	# If there is only 1 card, avoid division by zero.
	var intensity_factor = 1.0
	if default_center > 0:
		# This ensures the maximum Y drop is always equal to your 'curve_intensity' value
		intensity_factor = curve_intensity * zoom_scale.y / (default_center * default_center)

	var curve_floor = curve_intensity * 1.5 # Adjusted to scale with the new logic
	# ------------------------------------

	var dist_y = abs(mouse_pos.y - global_position.y)
	var vertical_proximity = 1.0 - clamp(dist_y / eff_radius, 0.0, 1.0)

	var mouse_rel_x = mouse_pos.x - (global_position.x + eff_offset.x)
	var mouse_index_float = (mouse_rel_x / eff_dist_h) + default_center

	var curve_apex = default_center
	if dynamic_fan_curve:
		curve_apex = lerp(default_center, clamp(mouse_index_float, 0.0, total_to_show - 1.0), vertical_proximity)

	var hovered_idx = round(mouse_index_float)
	var is_hovering_card = vertical_proximity > 0 and hovered_idx >= 0 and hovered_idx < total_to_show
	if is_hovering_card and abs(mouse_index_float - hovered_idx) > 0.4:
		is_hovering_card = false

	for i in range(total_to_show):
		var node = nodes[i] as CanvasItem
		if not node: continue

		var x_offset = (i - default_center) * eff_dist_h
		var y_offset = 0.0
		var dynamic_rotation = 0.0

		# 3. Apply Normalized Fan Logic
		if use_fan_curve:
			var dist_from_apex = i - curve_apex
			# Apply the intensity_factor here
			y_offset = (dist_from_apex * dist_from_apex) * intensity_factor

			# Rotation also needs to scale so the cards don't overlap too much in large hands
			var rot_factor = rotation_intensity / max(default_center, 1.0)
			var base_rot = dist_from_apex * deg_to_rad(rot_factor)
			dynamic_rotation = base_rot

		# 4. Interaction Features
		var final_z = base_z_index + i

		if is_hovering_card:
			if use_horizontal_spread:
				if i < hovered_idx:
					x_offset -= eff_spread
				elif i > hovered_idx:
					x_offset += eff_spread

			if i == int(hovered_idx):
				if use_hover_lift:
					y_offset += eff_lift
					dynamic_rotation = 0.0
				if use_z_index_hover:
					final_z += max_z_bonus

		# 5. Apply
		node.z_index = final_z
		var final_placement = global_position + eff_offset + Vector2(x_offset, y_offset)
		_arrange_node(node, final_placement, dynamic_rotation)

	var current_hovered = int(hovered_idx) if is_hovering_card else -1
	if current_hovered != _prev_hovered_idx:
		if current_hovered >= 0 and current_hovered < nodes.size():
			card_hovered.emit(nodes[current_hovered] as Node2D)
		else:
			card_hover_ended.emit()
		_prev_hovered_idx = current_hovered
# Add this function to your CardHand class
func get_index_at_position(global_pos: Vector2) -> int: ## Returns the child index (clamped) closest to the given global position based on horizontal spacing
	var total_nodes = get_child_count()
	if total_nodes == 0: return 0

	var default_center = (total_nodes - 1) / 2.0
	var zoom_scale := scale if (adapt_to_camera_zoom and _camera) else Vector2.ONE
	var eff_dist_h := distance_horizontal * zoom_scale.x
	var mouse_rel_x = global_pos.x - (global_position.x + offset.x * zoom_scale.x)

	# Calculate index based on horizontal spacing
	var idx = round((mouse_rel_x / eff_dist_h) + default_center)
	return int(clamp(idx, 0, total_nodes))

## Checks if a global position overlaps any collision area within the cards
func is_position_in_hand_zone(global_pos: Vector2) -> bool:
	for child in get_children():
		if _check_collision_recursive(child, global_pos):
			return true
	return false

func _check_collision_recursive(node: Node, global_pos: Vector2) -> bool:
	if node is CollisionShape2D:
		var shape = node.shape as RectangleShape2D
		if shape:
			# Convert global mouse position to the local space of the collision shape .
			var local_pos = node.to_local(global_pos)
			
			# A RectangleShape2D is centered at (0,0), so its bounds are 
			# from -size/2 to +size/2
			var rect = Rect2(-shape.size / 2.0, shape.size)
			
			if rect.has_point(local_pos):
				return true

	# Keep looking through the card's internal nodes (sprites, containers, etc.)
	for child in node.get_children():
		if _check_collision_recursive(child, global_pos):
			return true
			
	return false
