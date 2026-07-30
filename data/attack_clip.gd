class_name AttackClip extends Resource
## Datos visuales y temporales de un golpe animado. La animación mueve el arma visible;
## el consumidor decide qué hacer cuando AttackClipPlayer avisa la ventana de impacto.

## Nombre del clip dentro del AnimationPlayer que anima el esqueleto.
@export var clip: StringName = &""
## Segundo del clip donde comienza el tramo que se reproducirá.
@export var start_time: float = 0.0
## Segundo del clip donde termina el tramo; -1 reproduce hasta el final del clip.
@export var end_time: float = -1.0
## Duración real del golpe en segundos; 0 conserva la velocidad natural del tramo.
@export var duration: float = 0.0
## Momento normalizado 0-1 de la duración real en que debe abrirse el hitbox.
@export_range(0.0, 1.0) var hitbox_open: float = 0.0
## Momento normalizado 0-1 de la duración real en que debe cerrarse el hitbox.
@export_range(0.0, 1.0) var hitbox_close: float = 1.0
