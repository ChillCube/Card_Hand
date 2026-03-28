extends NodeArranger
class_name CardHand

func _init() -> void:
	# Arrangement Settings
	max_vertical = 1
	max_horizontal = 10
	centered = true
	
	# Spacing (Adjust distance_horizontal based on card width)
	distance_horizontal = 80.0 
	distance_vertical = 0.0
	
	# The "Fan" Effect
	curve_intensity = 15.0 
	rotation_intensity = 5.0
	
	# Visual Offset
	offset = Vector2(0, -50)
	
@export_group("Mouse Adaptation")
@export var mouse_reactive : bool = true
@export var reaction_radius : float = 300.0 
@export var mouse_lift_height : float = -50.0 
@export var horizontal_spread : float = 20.0 

@export_group("Z-Index Control")
## The base Z-index for cards in the hand
@export var base_z_index : int = 0
## How much the Z-index increases when the mouse is near
@export var max_z_bonus : int = 10 

func _process(delta: float) -> void:
	if continous_arranging:
		arrange()

func _arrange_nodes(nodes : Array[Node]) -> void:
	var total_to_show = min(nodes.size(), max_horizontal * max_vertical)
	if total_to_show <= 0: return
	
	var mouse_pos = get_global_mouse_position()
	var default_center = (total_to_show - 1) / 2.0
	
	# 1. Curve & Proximity Setup
	var natural_max_y = (default_center * default_center) * curve_intensity
	var curve_floor = natural_max_y * 1.5
	var dist_y = abs(mouse_pos.y - global_position.y)
	var vertical_proximity = 1.0 - clamp(dist_y / reaction_radius, 0.0, 1.0)
	
	# 2. Logic for the "Target" vs the "Visual"
	var mouse_rel_x = mouse_pos.x - (global_position.x + offset.x)
	var mouse_index_float = (mouse_rel_x / distance_horizontal) + default_center
	
	# The Visual Apex: Slides smoothly with the mouse
	var visual_apex = lerp(default_center, clamp(mouse_index_float, 0.0, total_to_show - 1.0), vertical_proximity)
	
	# The Click Target: Snaps to the nearest card for stability
	var hovered_idx = round(mouse_index_float)
	var is_hovering_card = vertical_proximity > 0 and hovered_idx >= 0 and hovered_idx < total_to_show
	# Ensure we are actually close to a card's center to trigger the "Spread"
	if is_hovering_card and abs(mouse_index_float - hovered_idx) > 0.4:
		is_hovering_card = false

	for i in range(total_to_show):
		var node = nodes[i] as CanvasItem
		if not node: continue
		
		# Base Horizontal Position
		var x_offset = (i - default_center) * distance_horizontal
		
		# 3. Dynamic Curve & Rotation (Visuals)
		# We use 'visual_apex' so the curve glides smoothly
		var dist_from_apex = i - visual_apex
		var y_offset = (dist_from_apex * dist_from_apex) * curve_intensity
		y_offset = min(y_offset, curve_floor) # Keep the bottom limit
		
		var floor_factor = clamp(y_offset / curve_floor, 0.0, 1.0) if curve_floor > 0 else 0.0
		var base_rot = dist_from_apex * deg_to_rad(rotation_intensity)
		var dynamic_rotation = lerp(base_rot, 0.0, floor_factor * 0.7)
		
		# 4. Binary UX Features (Stability)
		var final_z = base_z_index + i
		
		if is_hovering_card:
			# Spread: Neighbors move out of the way predictably
			if i < hovered_idx:
				x_offset -= horizontal_spread
			elif i > hovered_idx:
				x_offset += horizontal_spread
			
			# Pop: Only the active card lifts and flattens
			if i == int(hovered_idx):
				y_offset += mouse_lift_height
				dynamic_rotation = 0.0 # Perfect readability
				final_z += max_z_bonus

		# 5. Apply
		node.z_index = final_z
		var final_placement = global_position + offset + Vector2(x_offset, y_offset)
		_arrange_node(node, final_placement, dynamic_rotation)
