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
## Distancia de la cámara cuando jugador y target están a `lock_zoom_near_separation` metros o
## menos (zoom in en combate pegado).
@export_range(1.0, 60.0, 0.5) var lock_zoom_min_distance := 10.0
## Distancia de la cámara cuando jugador y target están a `lock_zoom_far_separation` metros o
## más (zoom out cuando se pelea a distancia).
@export_range(1.0, 60.0, 0.5) var lock_zoom_max_distance := 20.0
## Separación jugador-target (metros) en o por debajo de la cual la cámara usa `lock_zoom_min_distance`.
@export_range(0.0, 30.0, 0.5) var lock_zoom_near_separation := 3.0
## Separación jugador-target (metros) en o por encima de la cual la cámara usa `lock_zoom_max_distance`.
@export_range(0.0, 60.0, 0.5) var lock_zoom_far_separation := 15.0

@export_group("Wall slide")
## Mientras el jugador esta en wall slide, la camara se planta sola frente a la pared (el stick
## deja de rotarla). false = la pared no toca la camara, el yaw queda como lo dejaste.
@export var wall_slide_frame_enabled := true
## Cuanto se corre la camara desde la normal de la pared, en grados, hacia el lado que vas
## dejando atras (asi ves hacia donde te movas). 0 = justo detras tuyo, con la pared de frente;
## 90 = pegada a la linea de la pared, mirandola de canto. Default 45.
@export_range(0.0, 89.0, 1.0) var wall_slide_yaw_offset := 45.0
## El mismo corrimiento, pero cuando bajas (o subis) casi en vertical por la pared, sin recorrido
## lateral. A 90 la camara queda sobre la linea de la pared y la ve de canto: encuadre tipo 2D, el
## jugador cae en el plano de la pantalla. Entre este valor y `wall_slide_yaw_offset` se mezcla
## solo, segun cuan vertical sea tu movimiento. Igualarlo a `wall_slide_yaw_offset` desactiva la
## apertura vertical.
@export_range(0.0, 90.0, 1.0) var wall_slide_vertical_yaw_offset := 90.0
## Rapidez (m/s) sobre la pared por debajo de la cual la camara ignora el movimiento y sostiene el
## encuadre que ya tenia. Evita que un tramo casi quieto haga bailar el angulo.
@export_range(0.1, 20.0, 0.1) var wall_slide_motion_min_speed := 1.0
## Que tan rapido la camara se acomoda a ese encuadre al engancharte (y lo sigue en paredes
## curvas). Mas alto = mas seco; mas bajo = giro largo y suave.
@export_range(0.1, 20.0, 0.1) var wall_slide_yaw_damping := 4.0

@export_group("Seguimiento vertical")
## Cuántos metros por sobre/bajo de la última altura "asentada" sigue la cámara al target antes
## de congelarse: pasado el tope, deja de subir/bajar y el jugador sale de cuadro en vertical en
## vez de que la cámara lo persiga (ej. subiendo agarrado de algo). <= 0 desactiva el tope (sigue
## siempre, como antes). Sobreescribible por área con `CameraVerticalZone`.
@export_range(0.0, 60.0, 0.5) var vertical_follow_limit := 10.0
