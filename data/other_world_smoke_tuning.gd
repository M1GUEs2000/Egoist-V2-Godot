class_name OtherWorldSmokeTuning extends Resource
## Tuning global del humo de presencia del otro mundo.
## Lo leen todos los WorldMembership desde data/other_world_smoke_tuning.tres.

@export_group("Particulas")
## Particulas que componen el contorno de humo.
@export var particle_amount := 44
## Radio minimo del contorno de humo alrededor del dueno, en metros.
@export var radius := 0.58
## Segundos de vida de cada particula del humo.
@export var lifetime := 1.35
## Variacion aleatoria del humo. Mas alto = menos uniforme.
@export var randomness := 0.55
## Apertura del humo hacia arriba, en grados.
@export var spread := 38.0
## Velocidad minima con la que nace una particula.
@export var velocity_min := 0.08
## Velocidad maxima con la que nace una particula.
@export var velocity_max := 0.35
## Gravedad vertical del humo. Positivo = sube, negativo = baja.
@export var gravity := 0.16
## Frenado minimo de las particulas.
@export var damping_min := 0.08
## Frenado maximo de las particulas.
@export var damping_max := 0.25
## Escala minima de cada particula.
@export var scale_min := 0.45
## Escala maxima de cada particula.
@export var scale_max := 1.0

@export_group("Material")
## Tamano del quad/billboard que dibuja cada particula.
@export var quad_size := Vector2(0.9, 0.9)
## Transparencia del humo al nacer.
@export_range(0.0, 1.0, 0.01) var alpha_start := 0.0
## Transparencia del humo en la mitad de la vida.
@export_range(0.0, 1.0, 0.01) var alpha_mid := 0.5
## Transparencia del humo al morir.
@export_range(0.0, 1.0, 0.01) var alpha_end := 0.0

@export_group("Luz")
## Energia base del humo y luz cuando no hay pulso ni movimiento.
@export var min_energy := 0.35
## Energia maxima por movimiento, antes de sumar el pulso.
@export var max_energy := 0.9
## Velocidad que alcanza max_energy, en m/s.
@export var motion_speed := 4.0
## Alcance de la luz tenue del eco, en metros.
@export var light_range := 3.0
## Luz indirecta que aporta el humo al entorno.
@export var light_indirect_energy := 0.15
## Energia volumetrica de la luz del humo.
@export var light_volumetric_energy := 0.2

@export_group("Pulso")
## Energia del borde en la cresta del latido.
@export var rim_max_energy := 2.4
## Tiempo entre pulsos, en segundos. Mas alto = pulso mas lento.
@export var pulse_interval := 1.25
## Curva exponencial del pulso. 1 = lineal; 8+ = casi todo aparece al final.
@export_range(1.0, 24.0, 0.1) var pulse_exponent := 4.0
## Valor minimo del pulso para mostrar el borde y las siluetas de la estela.
@export_range(0.0, 1.0, 0.01) var pulse_visibility_threshold := 0.15
## Cuanto del pulso se suma al brillo del humo. 0 = el humo no late.
@export var smoke_pulse_boost := 0.35
## Brillo HDR aplicado directamente al color de emision de las particulas durante el pulso.
@export var particle_pulse_glow := 8.0
## Relleno tenue de la cascara. En 0 queda solo el borde.
@export var fill_energy := 0.03
## Finura del contorno encendido: mas alto = anillo mas fino.
@export var rim_sharpness := 3.0
