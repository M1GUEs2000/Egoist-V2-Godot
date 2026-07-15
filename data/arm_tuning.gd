class_name ArmTuning extends Resource
## Tuning del Brazo (puño remoto, habilidad permanente — no WeaponBase, no ocupa slot X/Y).
## Instancia .tres en data/. Primera pasada: solo combate, solo tap.

## Daño del golpe remoto. Bajo a propósito: el Brazo ayuda, no reemplaza a las armas.
@export var damage := 2.0
## Poise que come el golpe. Bajo a propósito: casi nunca quiebra por sí solo.
@export var stun: StunSettings
## Taps seguidos antes de forzar el cooldown.
@export var max_taps := 5
## Segundos bloqueado tras agotar max_taps.
@export var cooldown_duration := 3.0
## Segundos que el hitbox queda activo sobre el target (ventana de detección, no viaje visual).
@export var travel_time := 0.1
## Radio de la esfera de golpe que se posiciona sobre el target.
@export var hitbox_radius := 0.35
## Meter que gana un golpe conectado. Propio y bajo, independiente de WeaponTuning/PlayerTuning.
@export var meter_gain_on_hit := 1.0

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
