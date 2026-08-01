extends SceneTree
## Genera el mesh-nube que usa el humo estilizado como particula (res://visual/sm_cloud.res).
##
## Reemplaza el paso de Blender del pipeline clasico (esfera -> subsurf -> displace con Voronoi ->
## decimate): la malla se arma acá con una icosfera desplazada por ruido cellular. Se hace por script
## y no a mano en Blender porque asi la nube es reproducible y retuneable — cambiar SEED da otra
## nube sin volver a abrir un DCC ni reimportar un GLB.
##
## Icosfera y no UV sphere a proposito: no tiene costura ni polos, asi que todos los vertices son
## unicos y el desplazamiento no abre grietas. Como no lleva UV, el dissolve del shader es ruido
## procedural en espacio de objeto en vez de una textura.
##
##   & $GODOT --headless --path . --script res://tools/gen_cloud_mesh.gd

const OUT_PATH := "res://visual/sm_cloud.res"

## Subdivisiones de la icosfera. 2 = 320 tris / 162 vertices, el presupuesto de una particula que se
## dibuja 20 veces por emisor. 3 (1280 tris) solo si la nube se ve facetada de cerca.
const SUBDIVISIONS := 2
## Radio base en metros. La escala fina se tunea despues en la curva de escala del emisor.
const RADIUS := 0.5
## Semilla del ruido: es la perilla de "otra nube". Cambiarla regenera una silueta distinta.
const SEED := 1337
## Tamano de los bultos (el "size" del Voronoi). Mas alto = bultos mas chicos y mas numerosos.
const FREQUENCY := 1.4
## Cuanto deforma el ruido al radio, en fraccion del radio (el "intensity"). 0 = esfera lisa.
const DISPLACE := 0.45

func _init() -> void:
	var mesh := _build_cloud()
	var err := ResourceSaver.save(mesh, OUT_PATH)
	if err != OK:
		push_error("gen_cloud_mesh: no se pudo guardar %s (error %d)" % [OUT_PATH, err])
		quit(1)
		return
	var surface := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = surface[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = surface[Mesh.ARRAY_INDEX]
	print("gen_cloud_mesh: %s — %d vertices, %d tris" % [OUT_PATH, verts.size(), indices.size() / 3])
	quit()

func _build_cloud() -> ArrayMesh:
	var verts: Array[Vector3] = []
	var tris: Array[Vector3i] = []
	_icosahedron(verts, tris)
	for i in SUBDIVISIONS:
		_subdivide(verts, tris)

	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.seed = SEED
	noise.frequency = FREQUENCY
	noise.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN_SQUARED
	noise.cellular_return_type = FastNoiseLite.RETURN_DISTANCE

	# El ruido se muestrea sobre la esfera unitaria (antes de desplazar) para que dos vertices
	# vecinos lean puntos vecinos del campo: muestrear despues realimentaria la deformacion.
	for i in verts.size():
		var dir := verts[i].normalized()
		# Cellular devuelve ~[-1,1]; invertido, un valor alto = cerca de un feature point = bulto.
		var bump := 1.0 - (noise.get_noise_3dv(dir * 4.0) * 0.5 + 0.5)
		verts[i] = dir * RADIUS * (1.0 + DISPLACE * (bump - 0.5))

	return _to_mesh(verts, tris, _smooth_normals(verts, tris))

## Los 12 vertices y 20 caras del icosaedro regular, ya proyectados a la esfera unitaria.
func _icosahedron(verts: Array[Vector3], tris: Array[Vector3i]) -> void:
	var t := (1.0 + sqrt(5.0)) * 0.5
	for v in [
		Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
		Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1),
	]:
		verts.append((v as Vector3).normalized())
	for f in [
		Vector3i(0, 11, 5), Vector3i(0, 5, 1), Vector3i(0, 1, 7), Vector3i(0, 7, 10),
		Vector3i(0, 10, 11), Vector3i(1, 5, 9), Vector3i(5, 11, 4), Vector3i(11, 10, 2),
		Vector3i(10, 7, 6), Vector3i(7, 1, 8), Vector3i(3, 9, 4), Vector3i(3, 4, 2),
		Vector3i(3, 2, 6), Vector3i(3, 6, 8), Vector3i(3, 8, 9), Vector3i(4, 9, 5),
		Vector3i(2, 4, 11), Vector3i(6, 2, 10), Vector3i(8, 6, 7), Vector3i(9, 8, 1),
	]:
		tris.append(f)

## Parte cada triangulo en cuatro. El cache de puntos medios es lo que mantiene la malla soldada:
## sin el, cada cara crearia su propio vertice de arista y la nube saldria con costuras.
func _subdivide(verts: Array[Vector3], tris: Array[Vector3i]) -> void:
	var midpoints := {}
	var out: Array[Vector3i] = []
	for tri in tris:
		var a := _midpoint(verts, midpoints, tri.x, tri.y)
		var b := _midpoint(verts, midpoints, tri.y, tri.z)
		var c := _midpoint(verts, midpoints, tri.z, tri.x)
		out.append(Vector3i(tri.x, a, c))
		out.append(Vector3i(tri.y, b, a))
		out.append(Vector3i(tri.z, c, b))
		out.append(Vector3i(a, b, c))
	tris.assign(out)

func _midpoint(verts: Array[Vector3], cache: Dictionary, i: int, j: int) -> int:
	var key := Vector2i(mini(i, j), maxi(i, j))
	if cache.has(key):
		return cache[key]
	var index := verts.size()
	verts.append(((verts[i] + verts[j]) * 0.5).normalized())
	cache[key] = index
	return index

## Normal por vertice = promedio de las normales de las caras que lo tocan. Hay que recalcularlas
## si o si: la iluminacion cell-shaded se decide con dot(NORMAL, LIGHT), asi que con las normales
## de la esfera original la nube se sombrearia como una bola lisa y los bultos no se leerian.
func _smooth_normals(verts: Array[Vector3], tris: Array[Vector3i]) -> Array[Vector3]:
	var normals: Array[Vector3] = []
	normals.resize(verts.size())
	normals.fill(Vector3.ZERO)
	for tri in tris:
		# Sin normalizar: el area del triangulo pondera su aporte, que es lo que se quiere.
		var face := (verts[tri.y] - verts[tri.x]).cross(verts[tri.z] - verts[tri.x])
		normals[tri.x] += face
		normals[tri.y] += face
		normals[tri.z] += face
	for i in normals.size():
		# Un vertice degenerado dejaria una normal nula: se cae a la radial, que en una nube sirve.
		normals[i] = normals[i].normalized() if not normals[i].is_zero_approx() else verts[i].normalized()
	return normals

func _to_mesh(verts: Array[Vector3], tris: Array[Vector3i], normals: Array[Vector3]) -> ArrayMesh:
	var indices := PackedInt32Array()
	for tri in tris:
		indices.append(tri.x)
		indices.append(tri.y)
		indices.append(tri.z)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array(verts)
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array(normals)
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
