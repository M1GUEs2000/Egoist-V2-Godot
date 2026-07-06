class_name InputBuffer extends Node
## Reglas de feel (bóveda: Arquitectura): tap ejecuta al PRESS; >hold_threshold pasa a hold;
## input durante animación se guarda buffer_window y dispara en el primer frame válido.

@export var buffer_window := 0.15
@export var hold_threshold := 0.18
