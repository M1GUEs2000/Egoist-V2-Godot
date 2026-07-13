class_name WorldRiftTuning extends Resource
## Tuning de la grieta (WorldRift): la puerta temporal que queda abierta cuando algo se va al
## otro mundo. Instancia editable: data/world_rift_tuning.tres.
##
## El COLOR no se tunea aca: la grieta siempre lleva el del mundo DESTINO (el opuesto al actual,
## ver World.world_color), igual criterio que los bloques de world switch — anuncia adonde manda.

@export_group("Ventana")
## Segundos que la grieta queda abierta si nadie la cruza. Vencida, se cierra sola y NO cambia
## el mundo: la oportunidad se perdio.
@export_range(0.5, 30.0, 0.5) var lifetime := 6.0
## Radio del area que detecta al jugador, en metros. Es la boca de la grieta: chico = hay que
## apuntarle, grande = se cruza al pasar cerca.
@export_range(0.3, 5.0, 0.1) var trigger_radius := 1.1
## Segundos del cierre (se encoge y se apaga). Vale para los dos finales: cruzada o vencida.
@export_range(0.05, 2.0, 0.05) var close_time := 0.25

@export_group("Aviso de cierre")
## Segundos finales en los que la grieta parpadea avisando que se va a cerrar. 0 = sin aviso.
@export_range(0.0, 10.0, 0.25) var warning_time := 2.0
## Velocidad del parpadeo del aviso, en pulsos por segundo.
@export_range(0.5, 12.0, 0.5) var warning_pulse_speed := 4.0

@export_group("Brillo")
## Emision de la grieta abierta. Con el glow del WorldEnvironment cualquier valor alto se
## convierte en halo: subir con cuidado.
@export_range(0.0, 8.0, 0.05) var glow_energy := 2.2
## Energia de la luz real que la grieta derrama en el entorno. 0 = no ilumina nada.
@export_range(0.0, 8.0, 0.1) var light_energy := 2.5
## Alcance de esa luz, en metros.
@export_range(0.5, 20.0, 0.5) var light_range := 5.0
