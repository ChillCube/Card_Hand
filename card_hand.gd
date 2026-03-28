extends NodeArranger
class_name CardHand

func _init() -> void:
	# Arrangement Settings
	max_vertical = 1
	max_horizontal = 10
	centered = true
	distance_horizontal = 80.0 
	distance_vertical = 0.0
	curve_intensity = 35.0 
	rotation_intensity = 5.0
	offset = Vector2(0, -50)
	
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
@export var mouse_reactive : bool = true
@export var reaction_radius : float = 300.0 
@export var mouse_lift_height : float = -50.0 
@export var horizontal_spread : float = 20.0 

@export_group("Z-Index Control")
@export var base_z_index : int = 0
@export var max_z_bonus : int = 10 

func _process(_delta: float) -> void:
	if continous_arranging:
		arrange()

func _arrange_nodes(nodes : Array[Node]) -> void:
	var total_to_show = min(nodes.size(), max_horizontal * max_vertical)
	if total_to_show <= 0: return
	
	var mouse_pos = get_global_mouse_position()
	var default_center = (total_to_show - 1) / 2.0
	
	# --- NEW: Intensity Normalization ---
	# We calculate a factor so that the furthest card is always at a fixed Y offset.
	# If there is only 1 card, avoid division by zero.
	var intensity_factor = 1.0
	if default_center > 0:
		# This ensures the maximum Y drop is always equal to your 'curve_intensity' value
		intensity_factor = curve_intensity / (default_center * default_center)
	
	var curve_floor = curve_intensity * 1.5 # Adjusted to scale with the new logic
	# ------------------------------------

	var dist_y = abs(mouse_pos.y - global_position.y)
	var vertical_proximity = 1.0 - clamp(dist_y / reaction_radius, 0.0, 1.0)
	
	var mouse_rel_x = mouse_pos.x - (global_position.x + offset.x)
	var mouse_index_float = (mouse_rel_x / distance_horizontal) + default_center
	
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
		
		var x_offset = (i - default_center) * distance_horizontal
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
					x_offset -= horizontal_spread
				elif i > hovered_idx:
					x_offset += horizontal_spread
			
			if i == int(hovered_idx):
				if use_hover_lift:
					y_offset += mouse_lift_height
					dynamic_rotation = 0.0 
				if use_z_index_hover:
					final_z += max_z_bonus

		# 5. Apply
		node.z_index = final_z
		var final_placement = global_position + offset + Vector2(x_offset, y_offset)
		_arrange_node(node, final_placement, dynamic_rotation)
# Add this function to your CardHand class
func get_index_at_position(global_pos: Vector2) -> int:
	var total_nodes = get_child_count()
	if total_nodes == 0: return 0
	
	var default_center = (total_nodes - 1) / 2.0
	var mouse_rel_x = global_pos.x - (global_position.x + offset.x)
	
	# Calculate index based on horizontal spacing
	var idx = round((mouse_rel_x / distance_horizontal) + default_center)
	return int(clamp(idx, 0, total_nodes))
