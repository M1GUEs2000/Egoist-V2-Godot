class_name WallImpulseTuning extends Resource
## Tuning por pared de Wall Impulse. La direccion sale del primer input tangencial del
## jugador; este Resource solo define cuanto acelera y cual es su techo horizontal.

## Aceleracion horizontal constante mientras el jugador permanece enganchado a la pared.
@export var acceleration := 18.0
## Rapidez horizontal al capturar el rumbo. Evita arrancar quieto antes de acelerar.
@export var initial_speed := 5.0
## Inclinacion del carril respecto a la horizontal: 0 = recto, negativo = baja, positivo = sube.
@export_range(-89.0, 89.0, 1.0) var angle_degrees := 0.0
## Rapidez maxima del carril.
@export var max_speed := 16.0

## Activa el emisor verde creado automaticamente por cada WallImpulseSurface.
@export var particles_enabled := true
## Nombre del material que, en Blender, marca las caras que deben emitir. Solo esas caras
## siembran puntos: el resto de la malla y la colision quedan intactas.
@export var emit_material_name := "WallImpulseEmit"
## Cuantos puntos de emision se reparten sobre las caras marcadas, ponderados por area.
## Mas puntos = cobertura mas pareja; el costo es solo memoria de textura, no CPU por frame.
@export_range(16, 2048, 16) var emit_point_count := 256
## Apertura del chorro respecto a la normal de cada cara, en grados. 0 = perpendicular exacto,
## que es lo que hace que las motas salgan derecho del muro en vez de abrirse en abanico.
@export_range(0.0, 90.0, 1.0) var emit_spread_degrees := 0.0
## Gravedad vertical de las motas de la pared, en m/s². 0 = salen perpendiculares y se quedan
## horizontales; negativo las hace caer despues de salir; positivo las hace subir.
@export_range(-20.0, 20.0, 0.1) var emit_gravity := 0.0
## Oculta el material marcador en juego, reemplazandolo por el material base de la malla.
## Asi el marcador se ve en Blender para poder pintarlo, pero no se ve en el juego.
@export var hide_emit_material := true
## Cantidad maxima de motas simultaneas del emisor.
@export_range(1, 128, 1) var particle_amount := 64
## Vida de cada mota, en segundos.
@export_range(0.1, 3.0, 0.05) var particle_lifetime := 0.8
## Tamano del quad de cada mota, en metros.
@export_range(0.01, 1.0, 0.01) var particle_size := 0.12
## Rapidez con la que las motas salen del muro, en m/s. Su caida ya no depende de este valor:
## la controla emit_gravity para el emisor de pared.
@export var particle_speed := 1.5
## Intensidad HDR de las motas verdes. Subirlo hace que se lean mejor en paredes oscuras.
@export_range(0.0, 20.0, 0.25) var particle_emission_energy := 8.0
## Intensidad HDR de las motas que senalan la pared incluso cuando nadie la esta usando.
@export_range(0.0, 20.0, 0.25) var particle_idle_emission_energy := 2.0
## Luz verde que acompana al jugador mientras usa el carril.
@export_range(0.0, 10.0, 0.1) var particle_light_energy := 3.0
@export_range(0.5, 12.0, 0.25) var particle_light_range := 4.0
