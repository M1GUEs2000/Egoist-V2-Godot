class_name FloorSlideSurface extends Node
## Marca una plataforma como deslizante. Nodo hijo del cuerpo de la plataforma (StaticBody3D
## u otro cuerpo de mundo): PlayerFloorSlide lo busca entre los hijos del collider de suelo y
## usa su tuning. Sin este nodo la plataforma es suelo normal. Es solo-datos, sin logica
## (mismo rol descriptivo que WorldMembership, pero mudo): esto es lo que hace el slide "por
## plataforma" literal — cada instancia trae su propio Resource.

## Tuning de esta superficie (hielo / rampa). Cada plataforma puede llevar su propio .tres para
## ser mas o menos resbaladiza. Sin tuning asignado, la superficie se ignora.
@export var tuning: FloorSlideTuning
