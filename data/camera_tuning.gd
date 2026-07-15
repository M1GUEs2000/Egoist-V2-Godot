class_name CameraTuning extends Resource
## Tuning de CameraRig: encuadre isometrico + rotacion horizontal por stick.
## Instancia editable: data/camera_tuning.tres.

@export_group("Encuadre")
## Inclinacion isometrica fija.
@export_range(-89.0, 89.0, 0.5) var pitch := 30.0
## Yaw inicial de la camara (el offset del stick se suma encima; ya no hay recentrado).
@export_range(-180.0, 180.0, 0.5) var center_yaw := 45.0
## Distancia de la camara al target.
@export_range(1.0, 60.0, 0.5) var distance := 18.0
## Suavizado del follow (posicion). Mas alto = alcanza al target mas rapido.
@export_range(0.1, 20.0, 0.1) var damping := 5.0

@export_group("Rotacion por stick")
## Velocidad de giro mientras se mantiene el stick, en grados por segundo.
## La rotacion es libre (360, sin tope) y no se recentra sola.
@export_range(1.0, 360.0, 1.0) var yaw_speed := 90.0
## Zona muerta del eje camera_left/camera_right.
@export_range(0.0, 1.0, 0.01) var input_deadzone := 0.2

@export_group("Lock-on")
## Con lock activo, la cámara mira a un punto entre jugador y target en vez de solo al jugador.
## 0 = solo jugador, 1 = solo target, 0.5 = punto medio.
@export_range(0.0, 1.0, 0.05) var lock_focus_weight := 0.5
