extends RefCounted
class_name MarchingSquares

const EDGE_TOP := 0
const EDGE_RIGHT := 1
const EDGE_BOTTOM := 2
const EDGE_LEFT := 3

static func build_loops_from_image(image: Image, step: int, alpha_threshold: float = 0.5) -> Array[PackedVector2Array]:
	if image.is_empty() or step <= 0:
		return []

	var width := image.get_width()
	var height := image.get_height()
	var grid_w := int(ceil(width / float(step)))
	var grid_h := int(ceil(height / float(step)))

	var adjacency: Dictionary = {}
	var segments: Dictionary = {}

	# On ajoute une bordure vide autour de la grille pour fermer les contours qui touchent les bords de l'image.
	for cy in range(-1, grid_h):
		for cx in range(-1, grid_w):
			var case_id := _build_case_id(image, cx, cy, step, alpha_threshold)
			if case_id == 0 or case_id == 15:
				continue

			var case_segments := _segments_for_case(case_id, cx, cy)
			for edge_pair in case_segments:
				var p0: Vector2i = _edge_midpoint(cx, cy, edge_pair[0])
				var p1: Vector2i = _edge_midpoint(cx, cy, edge_pair[1])
				_add_segment(p0, p1, adjacency, segments)

	return _trace_loops(adjacency, segments, step)


static func _build_case_id(image: Image, cell_x: int, cell_y: int, step: int, alpha_threshold: float) -> int:
	var top_left := _is_solid_vertex(image, cell_x, cell_y, step, alpha_threshold)
	var top_right := _is_solid_vertex(image, cell_x + 1, cell_y, step, alpha_threshold)
	var bottom_right := _is_solid_vertex(image, cell_x + 1, cell_y + 1, step, alpha_threshold)
	var bottom_left := _is_solid_vertex(image, cell_x, cell_y + 1, step, alpha_threshold)

	return (int(top_left) << 3) | (int(top_right) << 2) | (int(bottom_right) << 1) | int(bottom_left)


static func _is_solid_vertex(image: Image, vx: int, vy: int, step: int, alpha_threshold: float) -> bool:
	var px := vx * step
	var py := vy * step

	if px < 0 or py < 0:
		return false
	if px >= image.get_width() or py >= image.get_height():
		return false

	return image.get_pixel(px, py).a > alpha_threshold


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


static func _trace_loops(adjacency: Dictionary, segments: Dictionary, step: int) -> Array[PackedVector2Array]:
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
		var polygon := _to_polygon(loop_vertices, step)
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


static func _to_polygon(vertices: Array[Vector2i], step: int) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	for v in vertices:
		polygon.append(Vector2(v.x * step * 0.5, v.y * step * 0.5))
	return polygon
