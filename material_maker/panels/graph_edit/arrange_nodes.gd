extends Button

@export var graph : GraphEdit = null
var grid_x_size := 350
var grid_x_distance := 75
var grid_y_distance := 50
var grid_y_size := 300

func _on_pressed() -> void:
	var node_info := {}

	var end_nodes: Array[GraphNode] = []

	for connection in graph.get_connection_list():
		if not graph.get_node(str(connection.to_node)) in node_info:
			node_info[graph.get_node(str(connection.to_node))] = [[],[], false]
		if not graph.get_node(str(connection.from_node)) in node_info:
			node_info[graph.get_node(str(connection.from_node))] = [[],[], false]

		node_info[graph.get_node(str(connection.to_node))][0].append(connection)
		node_info[graph.get_node(str(connection.from_node))][1].append(connection)

	# Sort connections
	for node in node_info:
		node_info[node][0].sort_custom(_sort_by_out_port)
		node_info[node][1].sort_custom(_sort_by_in_port)

	var deadend_nodes := []

	for node in graph.get_children():
		if node is GraphNode:
			if node.get_output_port_count() == 0:
				end_nodes.append(node)
				node_info[node][2] = true
			if not node in node_info:
				node_info[node] = [[],[], false]

	var target_info := {}

	## Process for X position
	for node in end_nodes:
		target_info[node] = {"pos_x":0}
		for connection in node_info[node][0]:
			process_connection_for_x_backwards(connection, target_info, node_info)

	for node in node_info:
		if node_info[node][2]:
			continue

		var root_node := get_main_branch_root_node(node, target_info, node_info)
		if root_node:
			for connection in node_info[root_node][1]:
				process_connection_for_x_forwards(connection, target_info, node_info)
		else:
			target_info[node] = {"branch_id": node.name, "pos_x": 0}
			for connection in node_info[node][0]:
				process_connection_for_x_backwards(connection, target_info, node_info, false, true)
			for connection in node_info[node][1]:
				process_connection_for_x_forwards(connection, target_info, node_info, false, true)

	## Reset processing
	for node in node_info:
		node_info[node][2] = false

	## Process for Y position
	for node in end_nodes:
		target_info[node]["pos_y"] = 0
		process_for_y_backwards(node, target_info, node_info)

	var column_sizes := {}
	for node in target_info:
		if not node is Node:
			continue
		column_sizes[target_info[node].pos_x] = max(column_sizes.get(target_info[node].pos_x, 0), node.size.x)

	var column_positions := {}
	for column in column_sizes:
		column_positions[column] = 0
		for x in range(column, 0):
			column_positions[column] += (column_sizes[x]+grid_x_distance)*sign(column)

	var separate_branch_frames := {}
	print(target_info)
	for i in target_info:
		if not i is Node:
			continue

		i.position_offset.x = column_positions[target_info[i].pos_x]# * grid_x_size
		if target_info[i].has("pos_y"):
			i.position_offset.y = target_info[i].pos_y# * grid_y_size
		else:
			print("NO Y! ", i.name)

		if target_info[i].has('branch_id'):
			if not separate_branch_frames.has(target_info[i].branch_id):
				var frame: GraphFrame
				if target_info.has("BRANCH"+target_info[i].branch_id):
					frame = target_info["BRANCH"+target_info[i].branch_id]
				if not frame:
					frame = GraphFrame.new()
					graph.add_child(frame)

				frame.name = str(target_info[i].branch_id)+"Frame"
				frame.title = "Unconnected Branch"
				separate_branch_frames[target_info[i].branch_id] = frame

			graph.attach_graph_element_to_frame(i.name, separate_branch_frames[target_info[i].branch_id].name)

	var offset := 0
	for frame:GraphFrame in separate_branch_frames.values():
		frame.position_offset.x = offset + grid_x_size
		frame.position_offset.y = 0
		offset = frame.position_offset.x + frame.size.x

	for node in graph.get_children():
		if node is GraphFrame:
			if graph.get_attached_nodes_of_frame(node.name).is_empty():
				node.queue_free()


func _sort_by_out_port(element1:Dictionary, element2:Dictionary) -> bool:
	return element2.to_port > element1.to_port


func _sort_by_in_port(element1:Dictionary, element2:Dictionary) -> bool:
	return element2.from_port > element1.from_port


func process_connection_for_x_backwards(connection:Dictionary, target_info:Dictionary, node_info: Dictionary, unprocessed_only := false, inverse_too:= false) -> void:
	var from_node := graph.get_node(str(connection.from_node))
	var to_node := graph.get_node(str(connection.to_node))

	if unprocessed_only and node_info[from_node][2]:
		return

	if not from_node in target_info:
		target_info[from_node] = {"pos_x": 0}

	target_info[from_node].pos_x = mini(target_info[to_node].pos_x - 1, target_info[from_node].pos_x)

	if target_info[to_node].has('branch_id'):
		target_info[from_node]["branch_id"] = target_info[to_node].branch_id

		if graph.get_element_frame(connection.from_node):
			target_info["BRANCH"+target_info[from_node]["branch_id"]] = graph.get_element_frame(connection.from_node)

	node_info[from_node][2] = true

	for incoming_connection in node_info[from_node][0]:
		process_connection_for_x_backwards(incoming_connection, target_info, node_info, unprocessed_only, inverse_too)

	if inverse_too:
		for incoming_connection in node_info[from_node][1]:
			process_connection_for_x_forwards(incoming_connection, target_info, node_info, true, inverse_too)


func process_connection_for_x_forwards(connection:Dictionary, target_info:Dictionary, node_info:Dictionary, unprocessed_only:= true, inverse_too:= true):
	var from_node := graph.get_node(str(connection.from_node))
	var to_node := graph.get_node(str(connection.to_node))

	if unprocessed_only and node_info[to_node][2]:
		return

	if not to_node in target_info:
		target_info[to_node] = {"pos_x": -999}

	target_info[to_node].pos_x = maxi(target_info[from_node].pos_x+1, target_info[to_node].pos_x)

	if target_info[from_node].has('branch_id'):
		target_info[to_node]["branch_id"] = target_info[from_node].branch_id
		if graph.get_element_frame(connection.to_node):
			target_info["BRANCH"+target_info[to_node]["branch_id"]] = graph.get_element_frame(connection.to_node)

	node_info[to_node][2] = true

	for incoming_connection in node_info[to_node][1]:
		process_connection_for_x_forwards(incoming_connection, target_info, node_info, unprocessed_only, inverse_too)

	if inverse_too:
		for incoming_connection in node_info[to_node][0]:
			process_connection_for_x_backwards(incoming_connection, target_info, node_info, true, inverse_too)


func process_for_y_backwards(node:GraphNode, target_info:Dictionary, node_info:Dictionary) -> Dictionary:
	var branch_width := 1
	var branch_heights := [node.size.y+grid_y_distance]
	var branch_nodes := []

	if not target_info[node].has("pos_y"):
		target_info[node]["pos_y"] = 0

	if node_info[node][2]:
		return {"width":branch_width, "heights": branch_heights, "nodes": branch_nodes}

	# While this is a straight chain (only one input)
	while node_info[node][0].size() == 1:
		# set processed
		node_info[node][2] = true

		branch_nodes.push_back(node)

		# if we cross into an already processed branch, we bail
		var from_node := graph.get_node(str(node_info[node][0][0].from_node))
		if node_info[from_node][2]:
			return {"width":branch_width, "heights": branch_heights, "nodes": branch_nodes}

		for i in range(target_info[node].pos_x-target_info[from_node].pos_x-1):
			branch_width += 1
			branch_heights.push_front(grid_y_distance*2)

		branch_width += 1
		branch_heights.push_front(from_node.size.y+grid_y_distance)

		node = from_node

		if not target_info[node].has("pos_y"):
			target_info[node]["pos_y"] = 0

	branch_nodes.push_back(node)
	node_info[node][2] = true

	# If there are no inputs (we reached the end of a branch)
	if node_info[node][0].size() == 0:
		return {"width":branch_width, "heights": branch_heights, "nodes": branch_nodes}

	# If this has multiple inputs
	var sub_branch_width := 0
	var sub_branch_heights := []
	for in_connection in node_info[node][0]:
		var branch_node := graph.get_node(str(in_connection.from_node))
		var branch_node_name := branch_node.name
		var branch_info := process_for_y_backwards(branch_node, target_info, node_info)

		for i in range(target_info[node].pos_x-target_info[branch_node].pos_x-1):
			branch_info.width += 1
			branch_info.heights.push_back(2*grid_y_distance)

		sub_branch_width = max(sub_branch_width, branch_info.width)

		var branch_y_offset := 0
		for x in range(branch_info.width):
			if x < len(sub_branch_heights):
				branch_y_offset = max(branch_y_offset, sub_branch_heights[-(x+1)])

		for new_node in branch_info["nodes"]:
			if not target_info[new_node].has("pos_y"):
				target_info[new_node]["pos_y"] = 0
			target_info[new_node].pos_y += branch_y_offset

		branch_nodes = branch_nodes + branch_info["nodes"]

		var updated_sub_branch_heights: PackedFloat32Array = []
		updated_sub_branch_heights.resize(sub_branch_width)

		for x in range(sub_branch_heights.size()):
			updated_sub_branch_heights[-sub_branch_heights.size()+x] += sub_branch_heights[x]

		for x in range(branch_info.heights.size()):
			updated_sub_branch_heights[-branch_info.heights.size()+x] = branch_info.heights[x] + branch_y_offset

		sub_branch_heights = updated_sub_branch_heights

	branch_width += sub_branch_width
	branch_heights = sub_branch_heights + branch_heights

	return {"width": branch_width, "heights":branch_heights, "nodes": branch_nodes}


func get_main_branch_root_node(node:GraphNode, target_info:Dictionary, node_info:Dictionary) -> GraphNode:
	if node_info[node][2]:
		return node
	for in_connection in node_info[node][0]:
		return get_main_branch_root_node(graph.get_node(str(in_connection.from_node)), target_info, node_info)
	return null
