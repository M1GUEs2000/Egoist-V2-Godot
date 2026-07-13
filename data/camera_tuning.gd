class_name CameraTuning extends Resource
## Tuning de CameraRig: encuadre isometrico + rotacion horizontal por stick.
## Instancia editable: data/camera_tuning.tres.

@export_group("Encuadre")
## Inclinacion isometrica fija.
@export_range(-89.0, 89.0, 0.5) var pitch := 30.0
## Yaw central: la posicion de reposo de la camara. Hoy es fija; variarla por area (marcador
## de zona que se la pise a CameraRig) queda como tarea aparte.
@export_range(-180.0, 180.0, 0.5) var center_yaw := 45.0
## Distancia de la camara al target.
@export_range(1.0, 60.0, 0.5) var distance := 18.0
## Suavizado del follow (posicion). Mas alto = alcanza al target mas rapido.
@export_range(0.1, 20.0, 0.1) var damping := 5.0

@export_group("Rotacion por stick")
## Maximo desvio horizontal permitido desde center_yaw, a cada lado. No deja rodear
## completamente al personaje: solo desviacion lateral.
@export_range(0.0, 90.0, 1.0) var max_yaw_offset := 30.0
## Velocidad de giro mientras se mantiene el stick, en grados por segundo.
@export_range(1.0, 360.0, 1.0) var yaw_speed := 90.0
## Segundos sin input del stick antes de empezar a recentrar.
@export_range(0.0, 5.0, 0.05) var recenter_delay := 1.2
## Suavizado del recentrado hacia center_yaw una vez que empieza.
@export_range(0.1, 20.0, 0.1) var recenter_speed := 4.0
## Zona muerta del eje camera_left/camera_right.
@export_range(0.0, 1.0, 0.01) var input_deadzone := 0.2
