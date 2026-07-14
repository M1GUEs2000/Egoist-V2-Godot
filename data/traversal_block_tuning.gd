class_name TraversalBlockTuning extends Resource
## Tuning visual compartido por los bloques de traversal componibles.

## Radio a partir del cual el glow empieza a subir por proximidad al jugador.
@export var proximity_radius := 7.0
## Emision de reposo cuando el jugador esta lejos: casi apagado, solo se distingue el color.
@export_range(0.0, 4.0, 0.05) var glow_min_energy := 0.2
## Emision al estar encima del bloque: bien encendido. Con albedo apagado, este es el
## que hace que "prenda" al acercarse; subilo si el glow se ve debil.
@export_range(0.0, 4.0, 0.05) var glow_max_energy := 0.8
## Alcance en metros de la luz real que emite el bloque hacia el entorno (piso, paredes).
@export var light_range := 4.0
## Energia maxima de esa luz cuando el jugador esta encima. 0 = el bloque no ilumina nada
## (solo brilla su superficie por emision). Subilo si queres que tiña mas fuerte el entorno.
@export_range(0.0, 8.0, 0.1) var light_energy_max := 2.5

@export_group("Derrame hacia abajo")
## Cono de luz que cae del bloque al piso, uno por feature (cada uno con su color puro).
## Alcance en metros: hasta que altura de caida sigue marcando el suelo.
@export var down_light_range := 12.0
## Apertura del cono en grados. Chico = mancha concentrada; grande = derrame ancho y difuso.
@export_range(1.0, 80.0, 1.0) var down_light_angle_degrees := 30.0
## Energia del cono con el jugador lejos (fuera de proximity_radius). Igual que el resto del
## bloque, el derrame prende por proximidad: 0 = apagado hasta que el jugador se acerca.
@export_range(0.0, 8.0, 0.1) var down_light_min_energy := 0.0
## Energia del cono con el jugador encima.
@export_range(0.0, 8.0, 0.1) var down_light_max_energy := 3.0

@export_group("Particulas hacia abajo")
## Motas del color de la feature cayendo del bloque. Se leen en el aire aunque no haya piso debajo.
@export var particles_enabled := true
## Cantidad de motas vivas a la vez POR FEATURE. Subir con cuidado: es costo por bloque.
@export_range(0, 64, 1) var particle_amount := 10
## Cuanto vive cada mota en segundos. Junto con la velocidad define que tan lejos cae.
@export_range(0.1, 8.0, 0.1) var particle_lifetime := 1.6
## Velocidad de caida en m/s (gravedad simulada del emisor, no la del mundo).
@export var particle_fall_speed := 3.0
## Lado de cada mota en metros.
@export_range(0.01, 0.5, 0.01) var particle_size := 0.07

@export_group("Flecha de direccion (bloque verde)")
## Largo de la vara, en metros, pegada a la cara -Z del bloque.
@export var arrow_shaft_length := 0.6
## Radio de la vara.
@export_range(0.01, 0.3, 0.01) var arrow_shaft_radius := 0.05
## Largo de la punta (cono).
@export var arrow_head_length := 0.35
## Radio de la base del cono.
@export_range(0.05, 0.5, 0.01) var arrow_head_radius := 0.16
## Transparencia de la flecha: 0 invisible, 1 solida.
@export_range(0.0, 1.0, 0.05) var arrow_alpha := 0.55
