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

## Segundos REALES que dura el golpe, estirando o comprimiendo el tramo para que entre. 0 = el tramo
## corre a su velocidad natural. Este es el numero que sincroniza animacion y mecanica: es tambien
## lo que dura el paso dentro de la secuencia.
@export var duration := 0.0

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
