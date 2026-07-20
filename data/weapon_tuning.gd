class_name WeaponTuning extends Resource
## Tuning común de cualquier arma (ex campos serializados de WeaponBase.cs).
## Cada arma concreta lo extiende (SwordTuning) y su instancia .tres vive en data/.

@export var swing_time := 0.1
## Recovery tras COMPLETAR un combo (finisher incluido), en segundos: ventana muerta en la
## que no puede arrancar otro combo (terrestre o aéreo; los taps se ignoran). Cortar el
## combo a mitad no lo cobra, y los cargados X/Y no se bloquean.
@export var combo_recovery := 0.7
@export var kills_to_upgrade := 20
@export var max_level := 3
@export var stun: StunSettings

@export_group("Mano")
## Altura de la mano sobre el origen del jugador, en metros. La mano orbita a esta altura.
@export var hand_height := 1.0
## Distancia de la mano al eje del jugador, en metros: el radio de la órbita. Subirlo
## despega los swings del cuerpo y agranda el arco que barre la hoja.
@export var hand_radius := 0.71
## Yaw de la pose de reposo de la mano, en grados alrededor del jugador. 0 = al frente,
## positivo = a la izquierda, negativo = a la derecha.
@export var hand_rest_yaw := -39.0

@export_group("Combo aéreo")
## Duración de cada golpe aéreo.
@export var air_step_time := 0.12
## Ventana para encadenar el siguiente tap aéreo.
@export var air_combo_window := 0.45
## Esperar esto tras el 1er golpe cambia de rama.
@export var air_wait_branch_threshold := 0.3
## Spike: velocidad hacia abajo en el finisher aéreo de la rama base.
@export var air_spike_down_speed := 30.0
## La 1ra vuelta de la rama espera eleva un poco al jugador.
@export var air_wait_spin_hop := 4.0
## Cuánto sostiene en el aire un golpe de esta arma (multiplica el air-hit-stall del
## Player). >1 = arma de pocos golpes pesados; 1.0 = base (Espada).
@export var air_stall_scale := 1.0

@export_group("Push")
## Arco del empujón (velocidad + altura + cierre), inyectable por arma. Lo usa cualquier
## ataque que arme un push, en tierra o en el aire — no solo el finisher aéreo.
@export var push: PushSettings
## Fracción del swing a la que se cobra el push (0.5 = a mitad del golpe). Bajarlo adelanta
## el impacto y deja los frames finales como recovery cancelable.
@export_range(0.0, 1.0, 0.05) var push_at := 1.0

@export_group("Parry (poise que inflige)")
## Poise que mete un parry hecho con un golpe NORMAL de esta arma (aéreo o suelo comparten valor).
## Solo poise, sin HP: si quiebra la reserva del enemigo → estado vulnerable cian + stun (ParryTuning).
@export var parry_poise_normal := 4.0
## Poise que mete un parry hecho con el CARGADO X (aéreo o suelo comparten valor).
@export var parry_poise_charged_x := 6.0
## Poise que mete un parry hecho con el CARGADO Y (aéreo o suelo comparten valor).
@export var parry_poise_charged_y := 8.0

@export_group("Sweet spot (carga)")
## Segundo de carga en que ABRE la ventana de sweet spot, contado desde el press (no desde el
## hold threshold). Soltar el cargado dentro de la ventana lo convierte en sweet spot; el efecto
## extra lo pone cada arma. Es TIMING, no nivel de carga: seguir cargando la deja pasar.
@export var sweet_spot_start := 0.6
## Cuanto queda abierta la ventana, en segundos. Ventana = [start, start + duration].
@export var sweet_spot_duration := 0.4
## Descuento de meter del cargado si sale en sweet spot. 0.3 = cuesta 30% menos barra.
@export_range(0.0, 1.0, 0.05) var sweet_spot_meter_discount := 0.3

@export_subgroup("Aura de la ventana")
## Motas que salen de la hoja mientras la ventana esta abierta: el tell de que hay que soltar
## AHORA. Mismas motas que los bloques de traversal (unshaded + billboard + additive).
@export var sweet_spot_particles_enabled := true
@export var sweet_spot_particle_color := World.COLOR_TRAVERSAL_CURSE
@export var sweet_spot_particle_emission := World.COLOR_TRAVERSAL_CURSE_EMISSION
## Motas vivas a la vez. Subirlo densifica el aura.
@export var sweet_spot_particle_amount := 24
## Segundos que vive cada mota.
@export var sweet_spot_particle_lifetime := 0.5
## Lado del quad de cada mota, en metros.
@export var sweet_spot_particle_size := 0.13
## Radio de la esfera alrededor de la hoja donde nacen, en metros.
@export var sweet_spot_particle_radius := 0.35
## Cuanto suben flotando, en m/s.
@export var sweet_spot_particle_rise_speed := 1.6

@export_group("VFX de impacto")
## Efecto (ParticleBurstVFX, FlipbookVFX o Binbun) que se instancia en cada golpe conectado.
## null = sin VFX. Contrato: one_shot/play()/finished (ver VfxInjector).
@export var hit_vfx_scene: PackedScene
## Escala del VFX de impacto al instanciarse.
@export var hit_vfx_scale := 1.0

## True si un hold sostenido `held` segundos cae dentro de la ventana de sweet spot.
## sweet_spot_duration <= 0 desactiva el sweet spot del arma entera.
func in_sweet_spot(held: float) -> bool:
	if sweet_spot_duration <= 0.0:
		return false
	return held >= sweet_spot_start and held <= sweet_spot_start + sweet_spot_duration

## Multiplicador del costo en barras de un cargado, ya con el descuento del sweet spot.
func meter_cost_scale(sweet_spot: bool) -> float:
	return 1.0 - sweet_spot_meter_discount if sweet_spot else 1.0
