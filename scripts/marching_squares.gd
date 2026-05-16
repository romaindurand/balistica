extends RefCounted
class_name MarchingSquares

const EDGE_TOP := 0
const EDGE_RIGHT := 1
const EDGE_BOTTOM := 2
const EDGE_LEFT := 3

static func build_loops_from_image(image: Image, step: int, alpha_threshold: float = 0.5) -> Array[PackedVector2Array]:
	return build_loops_from_image_with_sampling(image, step, alpha_threshold, 3, 0.75)


static func build_loops_from_image_with_sampling(image: Image, step: int, alpha_threshold: float = 0.5, sample_grid_size: int = 3, sample_radius_scale: float = 0.75) -> Array[PackedVector2Array]:
	if image.is_empty() or step <= 0:
		return []

	var width := image.get_width()
	var height := image.get_height()
	var grid_w := int(ceil(width / float(step)))
	var grid_h := int(ceil(height / float(step)))
	var sampling_grid := maxi(1, sample_grid_size)
	var sampling_radius := maxf(0.5, step * sample_radius_scale)

	var adjacency: Dictionary = {}
	var segments: Dictionary = {}
	var vertex_positions: Dictionary = {}

	# On ajoute une bordure vide autour de la grille pour fermer les contours qui touchent les bords de l'image.
	for cy in range(-1, grid_h):
		for cx in range(-1, grid_w):
			var top_left := _sample_vertex_field(image, cx, cy, step, alpha_threshold, sampling_grid, sampling_radius)
			var top_right := _sample_vertex_field(image, cx + 1, cy, step, alpha_threshold, sampling_grid, sampling_radius)
			var bottom_right := _sample_vertex_field(image, cx + 1, cy + 1, step, alpha_threshold, sampling_grid, sampling_radius)
			var bottom_left := _sample_vertex_field(image, cx, cy + 1, step, alpha_threshold, sampling_grid, sampling_radius)
			var case_id := _build_case_id(top_left, top_right, bottom_right, bottom_left, alpha_threshold)
			if case_id == 0 or case_id == 15:
				continue

			var case_segments := _segments_for_case(case_id, cx, cy)
			for edge_pair in case_segments:
				var p0: Vector2i = _edge_midpoint(cx, cy, edge_pair[0])
				var p1: Vector2i = _edge_midpoint(cx, cy, edge_pair[1])
				vertex_positions[p0] = _interpolate_edge_position(cx, cy, edge_pair[0], step, alpha_threshold, top_left, top_right, bottom_right, bottom_left)
				vertex_positions[p1] = _interpolate_edge_position(cx, cy, edge_pair[1], step, alpha_threshold, top_left, top_right, bottom_right, bottom_left)
				_add_segment(p0, p1, adjacency, segments)

	return _trace_loops(adjacency, segments, vertex_positions, step)


static func _build_case_id(top_left: float, top_right: float, bottom_right: float, bottom_left: float, alpha_threshold: float) -> int:
	return (int(top_left > alpha_threshold) << 3) | (int(top_right > alpha_threshold) << 2) | (int(bottom_right > alpha_threshold) << 1) | int(bottom_left > alpha_threshold)


static func _sample_vertex_field(image: Image, vx: int, vy: int, step: int, alpha_threshold: float, sample_grid_size: int, sample_radius: float) -> float:
	var center := Vector2(vx * step, vy * step)
	if sample_grid_size <= 1:
		return _sample_binary(image, center, alpha_threshold)

	var total := 0.0
	var sample_count := 0
	var span := sample_radius * 2.0

	for sy in range(sample_grid_size):
		var offset_y := -sample_radius + span * (sy / float(sample_grid_size - 1))
		for sx in range(sample_grid_size):
			var offset_x := -sample_radius + span * (sx / float(sample_grid_size - 1))
			total += _sample_binary(image, center + Vector2(offset_x, offset_y), alpha_threshold)
			sample_count += 1

	if sample_count == 0:
		return 0.0

	return total / sample_count


static func _sample_binary(image: Image, position: Vector2, alpha_threshold: float) -> float:
	var px := int(round(position.x))
	var py := int(round(position.y))

	if px < 0 or py < 0:
		return 0.0
	if px >= image.get_width() or py >= image.get_height():
		return 0.0

	return 1.0 if image.get_pixel(px, py).a > alpha_threshold else 0.0


static func _segments_for_case(case_id: int, cell_x: int, cell_y: int) -> Array:
	match case_id:
		1:
			return [[EDGE_LEFT, EDGE_BOTTOM]]
		2:
			return [[EDGE_BOTTOM, EDGE_RIGHT]]
		3:
			return [[EDGE_LEFT, EDGE_RIGHT]]
		4:
			return [[EDGE_TOP, EDGE_RIGHT]]
		5:
			if ((cell_x + cell_y) & 1) == 0:
				return [[EDGE_TOP, EDGE_LEFT], [EDGE_BOTTOM, EDGE_RIGHT]]
			return [[EDGE_TOP, EDGE_RIGHT], [EDGE_BOTTOM, EDGE_LEFT]]
		6:
			return [[EDGE_TOP, EDGE_BOTTOM]]
		7:
			return [[EDGE_TOP, EDGE_LEFT]]
		8:
			return [[EDGE_TOP, EDGE_LEFT]]
		9:
			return [[EDGE_TOP, EDGE_BOTTOM]]
		10:
			if ((cell_x + cell_y) & 1) == 0:
				return [[EDGE_TOP, EDGE_RIGHT], [EDGE_BOTTOM, EDGE_LEFT]]
			return [[EDGE_TOP, EDGE_LEFT], [EDGE_BOTTOM, EDGE_RIGHT]]
		11:
			return [[EDGE_TOP, EDGE_RIGHT]]
		12:
			return [[EDGE_LEFT, EDGE_RIGHT]]
		13:
			return [[EDGE_BOTTOM, EDGE_RIGHT]]
		14:
			return [[EDGE_LEFT, EDGE_BOTTOM]]
		_:
			return []


static func _edge_midpoint(cell_x: int, cell_y: int, edge_id: int) -> Vector2i:
	var hx := cell_x * 2
	var hy := cell_y * 2

	match edge_id:
		EDGE_TOP:
			return Vector2i(hx + 1, hy)
		EDGE_RIGHT:
			return Vector2i(hx + 2, hy + 1)
		EDGE_BOTTOM:
			return Vector2i(hx + 1, hy + 2)
		EDGE_LEFT:
			return Vector2i(hx, hy + 1)
		_:
			return Vector2i(hx, hy)


static func _interpolate_edge_position(cell_x: int, cell_y: int, edge_id: int, step: int, alpha_threshold: float, top_left: float, top_right: float, bottom_right: float, bottom_left: float) -> Vector2:
	var origin := Vector2(cell_x * step, cell_y * step)

	match edge_id:
		EDGE_TOP:
			return origin + Vector2(_interpolation_factor(top_left, top_right, alpha_threshold) * step, 0.0)
		EDGE_RIGHT:
			return origin + Vector2(step, _interpolation_factor(top_right, bottom_right, alpha_threshold) * step)
		EDGE_BOTTOM:
			return origin + Vector2(_interpolation_factor(bottom_left, bottom_right, alpha_threshold) * step, step)
		EDGE_LEFT:
			return origin + Vector2(0.0, _interpolation_factor(top_left, bottom_left, alpha_threshold) * step)
		_:
			return origin


static func _interpolation_factor(a: float, b: float, threshold: float) -> float:
	var delta := b - a
	if absf(delta) <= 0.00001:
		return 0.5
	return clampf((threshold - a) / delta, 0.0, 1.0)


static func _add_segment(p0: Vector2i, p1: Vector2i, adjacency: Dictionary, segments: Dictionary):
	if p0 == p1:
		return

	var key := _edge_key(p0, p1)
	if segments.has(key):
		return

	segments[key] = [p0, p1]

	if not adjacency.has(p0):
		adjacency[p0] = []
	if not adjacency.has(p1):
		adjacency[p1] = []

	var n0: Array = adjacency[p0]
	if not n0.has(p1):
		n0.append(p1)

	var n1: Array = adjacency[p1]
	if not n1.has(p0):
		n1.append(p0)


static func _edge_key(a: Vector2i, b: Vector2i) -> String:
	if _vec_less_or_equal(a, b):
		return "%d,%d|%d,%d" % [a.x, a.y, b.x, b.y]
	return "%d,%d|%d,%d" % [b.x, b.y, a.x, a.y]


static func _vec_less_or_equal(a: Vector2i, b: Vector2i) -> bool:
	if a.x < b.x:
		return true
	if a.x > b.x:
		return false
	return a.y <= b.y


static func _trace_loops(adjacency: Dictionary, segments: Dictionary, vertex_positions: Dictionary, step: int) -> Array[PackedVector2Array]:
	var loops: Array[PackedVector2Array] = []
	var visited: Dictionary = {}
	var segment_keys: Array = segments.keys()
	segment_keys.sort()

	for start_key in segment_keys:
		if visited.has(start_key):
			continue

		var seg: Array = segments[start_key]
		var start_vertex: Vector2i = seg[0]
		var current_vertex: Vector2i = seg[1]
		var previous_vertex: Vector2i = start_vertex

		var loop_vertices: Array[Vector2i] = [start_vertex, current_vertex]
		visited[start_key] = true

		var guard := 0
		var closed := false
		while guard < 100000:
			guard += 1
			if current_vertex == start_vertex:
				closed = true
				break

			var next_vertex := _pick_next_vertex(previous_vertex, current_vertex, adjacency, visited)
			if next_vertex == Vector2i(2147483647, 2147483647):
				break

			visited[_edge_key(current_vertex, next_vertex)] = true
			previous_vertex = current_vertex
			current_vertex = next_vertex
			loop_vertices.append(current_vertex)

		if not closed:
			continue

		if loop_vertices.size() < 4:
			continue

		# On supprime le dernier point identique au premier; CollisionPolygon2D ferme déjà la boucle.
		loop_vertices.pop_back()
		var polygon := _to_polygon(loop_vertices, vertex_positions, step)
		if polygon.size() >= 3:
			loops.append(polygon)

	return loops


static func _pick_next_vertex(previous_vertex: Vector2i, current_vertex: Vector2i, adjacency: Dictionary, visited: Dictionary) -> Vector2i:
	if not adjacency.has(current_vertex):
		return Vector2i(2147483647, 2147483647)

	var neighbors: Array = adjacency[current_vertex]
	neighbors.sort_custom(func(a: Vector2i, b: Vector2i):
		if a.x == b.x:
			return a.y < b.y
		return a.x < b.x
	)

	for candidate in neighbors:
		if candidate == previous_vertex:
			continue
		var key := _edge_key(current_vertex, candidate)
		if visited.has(key):
			continue
		return candidate

	return Vector2i(2147483647, 2147483647)


static func _to_polygon(vertices: Array[Vector2i], vertex_positions: Dictionary, step: int) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	for v in vertices:
		if vertex_positions.has(v):
			polygon.append(vertex_positions[v])
		else:
			polygon.append(Vector2(v.x * step * 0.5, v.y * step * 0.5))
	return polygon
