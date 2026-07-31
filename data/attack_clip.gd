@tool
class_name AttackClip extends Resource
## CONTRATO CONGELADO. Un tramo de animacion que hace de golpe: que clip, desde donde hasta donde,
## cuanto dura de verdad, y en que parte de ese tramo el hitbox esta abierto.
##
## Es la unica superficie compartida entre los dos trabajos en curso:
##
##   - El ANIMADOR (combat/attack_clip_player.gd) lo reproduce sobre el maniqui, lleva el hitbox
##     colgado del hueso de la mano y avisa con senales cuando abre y cierra.
##   - El SECUENCIADOR (WeaponBase.run_attack_sequence) lo pone dentro de un AttackStep y decide
##     que dano, que perfil de movimiento y que sigue despues.
##
## Ninguno de los dos edita este archivo sin avisar al otro: si cambia un campo, se rompen los dos
## lados a la vez y en silencio (los .tres serializan por nombre).
##
## POR QUE ESTE RESOURCE EXISTE: hoy el golpe visual y el golpe mecanico son dos cosas que nunca
## coincidieron. El clip del maniqui sale por play_visual_clip con sus tiempos hardcodeados en
## constantes del arma (ANIM_HEAVY con HEAVY_AIR_Y_START/END, o literales como 0.2 y 0.8), mientras
## el dano lo hace una espada invisible que orbita al Player movida por tweens procedurales, con la
## ventana de dano abierta durante TODO el swing en vez de en el momento del impacto. Este Resource
## es donde esos numeros dejan de estar en el codigo y pasan a ser tuning.
##
## UNIDADES: `start_time`, `end_time` y `duration` van en SEGUNDOS, no en frames. Es 3D con esqueleto
## UAL y el AnimationPlayer de Godot trabaja en segundos.

## Nombre del clip en el AnimationPlayer del maniqui (ej: &"Sword_Regular_A"). Tiene que existir en
## la libreria ya cargada: PlayerAnimationController copia UAL1 y los .glb sueltos a la libreria de
## UAL2 en runtime. Un nombre que no existe no es un error de compilacion, asi que el animador avisa
## con push_warning en vez de fallar en silencio.
@export var clip: StringName = &""

## Segundo del clip donde arranca el tramo. Sirve para usar un pedazo de una animacion larga: el
## hachazo aereo de la Espada es un recorte de Sword_Heavy_Combo, no el clip entero.
@export var start_time := 0.0

## Segundo del clip donde termina el tramo. -1 = hasta el final del clip.
@export var end_time := -1.0

## Cuanto MAS RAPIDO sale este golpe que sus vecinos, en porcentaje. 0 = la duracion que le toca por
## defecto (el `step_time` de la cadena, o el `swing_time` del arma); 20 = un 20% mas rapido; -50 =
## la mitad de velocidad, o sea el doble de largo.
##
## Reemplaza al viejo `duration` en segundos absolutos (2026-07-30). El motivo es que ese numero
## obligaba a saber de antemano cuanto dura el golpe para poder decir "este sale un toque mas
## rapido", y encima el valor quedaba desconectado del resto de la cadena: cambiar el `step_time`
## dejaba el override viejo pisando igual. Un porcentaje se lee solo y sigue a su base.
##
## Es el numero que sincroniza animacion y mecanica: el paso dura esto Y el tramo de clip se estira
## o comprime para entrar justo.
@export_range(-90.0, 300.0, 1.0, "or_greater", "suffix:%") var speed_bonus := 0.0

## Segundos reales del golpe, ya resueltos por quien lo dispara (WeaponBase calcula la base de la
## cadena y le aplica `speed_bonus`). NO es @export a proposito: no es tuning, es el resultado del
## tuning viajando hasta el animador, y exportarlo lo volveria un segundo lugar donde tocar la
## duracion. `WeaponBase.play_attack_clip` duplica el clip antes de escribirlo, asi que nunca se
## escribe el .tres.
var duration := 0.0

## Aplica `speed_bonus` sobre la duracion que le tocaria al golpe. Vive aca y no en cada consumidor
## para que el arma y el animador no puedan calcularla distinto.
##
## El factor se recorta en 0.1: un `speed_bonus` de -100 seria una division por cero y un golpe
## eterno. El @export ya limita a -90, pero un .tres viejo o un `or_greater` pueden traer cualquier
## cosa.
func scaled_duration(base: float) -> float:
	return base / maxf(0.1, 1.0 + speed_bonus / 100.0)

## Fraccion del golpe en la que el hitbox ABRE, normalizada 0-1 sobre `duration`. Va normalizado a
## proposito: cambiar la duracion del golpe no tiene que invalidar la ventana de dano. 0 = abre con
## el golpe.
@export_range(0.0, 1.0, 0.01) var hitbox_open := 0.0

## Fraccion del golpe en la que el hitbox CIERRA, normalizada igual que `hitbox_open`. 1 = cierra al
## terminar el golpe (el comportamiento de hoy, donde la ventana dura todo el swing).
@export_range(0.0, 1.0, 0.01) var hitbox_close := 1.0

## Segundos que el hitbox pasa abierto dentro de un golpe de `total` segundos. Vive aca y no en cada
## consumidor para que el animador y el secuenciador no puedan calcularla distinto.
func open_seconds(total: float) -> float:
	return maxf(0.0, (hitbox_close - hitbox_open) * total)

## Segundos desde el inicio del golpe hasta que el hitbox abre.
func open_delay(total: float) -> float:
	return maxf(0.0, hitbox_open * total)

# ---- Desplegable de `clip` en el inspector (solo editor) ----
#
# `clip` es un StringName escrito a mano y un nombre inexistente NO es error de compilacion: sale un
# push_warning y el golpe se queda sin dibujo. Esto convierte el campo en un desplegable con los
# clips que de verdad van a estar en la libreria del maniqui en runtime.
#
# Es HINT_ENUM_SUGGESTION y no HINT_ENUM a proposito: sugiere pero deja escribir a mano, porque el
# proyecto tiene clips WIP que se dan de alta despues (para eso existe CUSTOM_ANIMATIONS).
#
# No toca ningun @export: no agrega, quita ni renombra campos, asi que los .tres existentes valen
# tal cual y el CONTRATO CONGELADO de arriba sigue intacto. Solo cambia como lo dibuja el inspector.

## Lista de clips, una por linea, generada por `tools/generate_clip_names.gd`.
##
## POR QUE UN ARCHIVO Y NO LEER LOS .glb ACA: el primer intento instanciaba el glb de UAL2 dentro de
## `_validate_property` para sacarle `get_animation_list()`. El inspector llama a esa funcion tambien
## MIENTRAS corre el escaneo del EditorFileSystem, asi que instanciar una escena ahi reentra al
## escaneo en curso y **cuelga el editor**. Leer un txt es barato y no toca el filesystem del editor.
##
## El costo es que la lista se regenera a mano al agregar animaciones. Es el intercambio correcto:
## una lista vencida solo pierde una sugerencia (el campo sigue aceptando texto libre), mientras que
## la version cara se llevaba puesto el editor.
const CLIP_NAMES_PATH := "res://data/clip_names.txt"

## Cache por sesion de editor: el inspector redibuja seguido y esto no cambia entre redibujos.
static var _clip_names := PackedStringArray()

func _validate_property(property: Dictionary) -> void:
	if property.name != "clip" or not Engine.is_editor_hint():
		return
	var names := _available_clips()
	if names.is_empty():
		return
	property.hint = PROPERTY_HINT_ENUM_SUGGESTION
	property.hint_string = ",".join(names)

## Sin archivo no hay sugerencia y el campo se comporta como antes: texto libre. Que falte no es un
## error, es una lista sin generar.
static func _available_clips() -> PackedStringArray:
	if not _clip_names.is_empty():
		return _clip_names
	if not FileAccess.file_exists(CLIP_NAMES_PATH):
		return PackedStringArray()
	var text := FileAccess.get_file_as_string(CLIP_NAMES_PATH)
	for line in text.split("\n", false):
		var clip_name := line.strip_edges()
		# `,` es el separador del hint_string: un nombre con coma partiria la lista en dos entradas.
		if clip_name != "" and not clip_name.begins_with("#") and not clip_name.contains(","):
			_clip_names.append(clip_name)
	return _clip_names
