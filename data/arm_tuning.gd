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
