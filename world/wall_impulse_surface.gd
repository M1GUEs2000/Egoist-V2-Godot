class_name WallImpulseSurface extends Node3D
## Marca un StaticBody3D como pared de impulso. PlayerWallSlide captura el primer input
## tangencial valido al engancharse y acelera en esa direccion hasta perder el contacto.

## Cada pared puede usar un .tres distinto para tunear su aceleracion y velocidad maxima.
@export var tuning: WallImpulseTuning
## Particulas verdes locales que se prenden solo mientras el player usa esta pared.
@export var particles: GPUParticles3D

func set_impulse_active(active: bool) -> void:
	if particles != null and particles.emitting != active:
		particles.emitting = active
