class_name ArmTuning extends Resource
## Tuning del Brazo (puño remoto, habilidad permanente — no WeaponBase, no ocupa slot X/Y).
## Instancia .tres en data/. Primera pasada: solo combate, solo tap.

## Daño del golpe remoto. Bajo a propósito: el Brazo ayuda, no reemplaza a las armas.
@export var damage := 2.0
## Poise que come el golpe. Bajo a propósito: casi nunca quiebra por sí solo.
@export var stun: StunSettings
## Golpes de brazo acumulables (cargas). Es el techo de la reserva, no una racha: se gastan de a
## uno y se regeneran de a uno (ver cooldown_duration).
@export var max_taps := 5
## Segundos que tarda en volver UN golpe. No es un bloqueo por agotamiento: el reloj corre apenas
## la reserva no esta completa, asi que gastar un solo golpe ya empieza a devolverlo. Si faltan
## varios se recuperan de a uno cada `cooldown_duration`. Gastar mientras corre no lo reinicia.
@export var cooldown_duration := 3.0
## Segundos minimos entre dos golpes consecutivos (cadencia). Aplastar el input mas rapido que
## esto no pega mas rapido: los taps de mas se guardan en cola y salen a este ritmo, sin
## perderse, hasta agotar max_taps.
@export var tap_cadence := 0.15
## Segundos que el hitbox queda activo sobre el target (ventana de detección, no viaje visual).
@export var travel_time := 0.1
## Radio de la esfera de golpe que se posiciona sobre el target.
@export var hitbox_radius := 0.35
## Meter que gana un golpe conectado. Propio y bajo, independiente de WeaponTuning/PlayerTuning.
@export var meter_gain_on_hit := 1.0
## Segundos que el Brazo sostiene al jugador al conectar en el aire: un Floater de hold total
## (fall_scale 0), el mismo primitivo que usan los demas ataques. Mucho mas corto que el air stall
## del arma (PlayerTuning.air_stall_*) y sin escalado por combo: es una duracion fija por golpe.
## 0 = sin hang vertical.
@export var air_hang_duration := 0.3
## Fraccion del momentum HORIZONTAL (bump) que sobrevive cada golpe aereo del Brazo: a diferencia
## de la vertical (pausa que conserva), la horizontal DECELERA — cada golpe la frena. 1.0 = no
## frena, 0.5 = la parte a la mitad por golpe, 0.0 = la mata.
@export_range(0.0, 1.0) var air_horizontal_keep := 0.5

@export_group("Traversal (bloques verdes)")
## Alcance del brazo para marcar bloques de dash (verdes). Propio, no comparte el
## `lock_max_range` de combate: el traversal suele estar más lejos que un enemigo en pelea.
@export var traversal_lock_max_range := 16.0
## Cono horizontal (grados) respecto al forward del jugador para marcar un bloque de dash.
@export var traversal_lock_half_angle := 45.0
## Cono vertical (grados) respecto al plano horizontal para marcar un bloque de dash.
@export var traversal_lock_vertical_half_angle := 35.0
## Metros que se suma en Y al teletransportar al jugador sobre el bloque marcado.
@export var teleport_height_offset := 0.0
## Segundos que tarda el jugador en llegar al bloque marcado (dash forzado hacia el, ver
## PlayerDash.force_dash). Mas alto = viaje mas lento y visible; 0 no es instantaneo real,
## PlayerDash lo clampea a un minimo.
@export var teleport_duration := 0.25
## Metros sobre la base del bloque donde flota el punto morado del marcador (ver PlayerArm._process).
@export var traversal_marker_height := 1.1
## Segundos de cooldown del brazo tras teletransportar y activar un bloque de dash. Evita
## encadenar teletransportes instantaneos entre bloques verdes seguidos.
@export var traversal_cooldown_duration := 1.0

@export_group("VFX")
## Efecto que vive permanentemente sobre el hombro izquierdo Y que aparece en cada impacto del
## brazo (una sola escena para los dos usos). Cambialo por cualquier escena de VFX; si el nodo
## raiz expone `one_shot`/`play()` (como los packs Binbun) se maneja el loop/one-shot solo. Si
## es null, no se instancia nada.
@export var vfx_scene: PackedScene
## Hueso del esqueleto UAL donde cuelga el aura permanente. `clavicle_l` = hombro izquierdo.
@export var vfx_aura_bone: StringName = &"clavicle_l"
## Offset local (m) del aura respecto al hueso. +Y la sube "justo arriba del hombro".
@export var vfx_aura_offset := Vector3(0.0, 0.2, 0.0)
## Escala del aura permanente. El efecto de fabrica es grande (~1.5 m); bajalo para que quepa en
## el hombro. A tunear mirando el juego.
@export var vfx_aura_scale := 0.15
## Escala del VFX one-shot que aparece en el punto de impacto. A tunear mirando el juego.
@export var vfx_impact_scale := 0.25
## Si esta activo, pinta el VFX (aura e impacto) con los colores de abajo. Solo funciona en
## efectos que expongan primary_color/secondary_color/emission (los packs Binbun lo hacen). En
## false, el efecto conserva el color con el que viene.
@export var vfx_tint := false
## Color primario (nucleo) del efecto cuando vfx_tint esta activo.
@export var vfx_primary_color := Color(1.0, 0.8, 0.2)
## Color secundario (bordes/humo) del efecto cuando vfx_tint esta activo.
@export var vfx_secondary_color := Color(1.0, 0.4, 0.1)
## Intensidad de emision (glow). Mas alto = mas brillante. Solo si vfx_tint esta activo.
@export var vfx_emission := 4.0
