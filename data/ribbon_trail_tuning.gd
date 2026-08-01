class_name RibbonTrailTuning extends Resource
## Perfil visual compartido por las cintas procedurales: hoja y sprint. Solo describe look y forma;
## cuando empieza o termina de muestrear lo decide el sistema dueño de cada efecto.

@export_group("Color")
## Gradiente por edad: izquierda = muestra nueva, derecha = cola a punto de morir. Su alpha apaga
## la cinta de forma continua.
@export var gradient: Gradient
## Multiplicador de brillo sobre el gradiente. >1 alimenta el bloom.
@export_range(0.0, 8.0, 0.05) var brightness := 1.6

@export_group("Forma")
## Segundos que sobrevive una muestra. Define el largo espacial de la cola.
@export_range(0.02, 1.0, 0.01, "suffix:s") var lifetime := 0.25
## Afina el lado UV.y = 0. Para una cinta pareja, usar 0.
@export_range(0.0, 1.0, 0.01) var base_fade := 0.55
## Distancia minima recorrida antes de agregar otra muestra.
@export_range(0.0, 0.5, 0.005, "suffix:m") var min_sample_distance := 0.01
## Salto entre frames que corta la cinta para no tender una banda sobre un teleport.
@export_range(0.1, 20.0, 0.1, "suffix:m") var max_segment_length := 3.0

@export_group("Erosion")
## Ruido procedural que rompe el borde de la cola. Vacio = solo alpha del gradiente.
@export var erosion_noise: Texture2D
@export var erosion_scale := Vector2(2.0, 1.0)
@export var erosion_scroll := Vector2(-1.2, 0.0)
@export_range(0.0, 1.0, 0.01) var erosion_strength := 0.75
@export_range(0.01, 1.0, 0.01) var erosion_softness := 0.35
