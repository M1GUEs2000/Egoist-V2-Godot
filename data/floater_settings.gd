class_name FloaterSettings extends Resource
## Perfil de una suspension para un Floater (ver combat/floater.gd y obsidian/Plan Autoridad Vertical).
## Simetrico a MoverSettings: lo define QUIEN ataca (arma/ataque/enemigo), no el receptor, y cada
## golpe lleva su propio perfil, asi un mismo ataque puede colgar distinto al Player y al Enemy.
## Instancias .tres o subresources embebidas viven en data/ dentro de SwordTuning, MaceTuning, etc.
##
## Un Floater SOLO suspende a su dueno. "Colgar a ambos" = el ataque emite DOS FloaterSettings, uno
## por cuerpo; no hay fisica compartida ni un target=BOTH dentro del componente.

## Segundos que dura la suspension. 0 = no detona Floater (el cuerpo cae normal).
@export var duration := 0.0
## Escala de caida mientras dura: 0.0 = hold total (vertical fijada en 0), 1.0 = gravedad normal,
## intermedio = deriva lenta (ej. 0.15 = cae al 15%, como el juggle). Ver combat/floater.gd.
@export_range(0.0, 1.0) var fall_scale := 0.0
