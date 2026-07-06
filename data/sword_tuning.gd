class_name SwordTuning extends WeaponTuning
## Tuning de la Espada (ex SwordWeapon.cs). Instancia editable: data/sword_tuning.tres.
## Los tamaños de los hitboxes (hoja, disco aéreo, launcher) viven como shapes en
## sword.tscn, igual que la cápsula del player.

@export_group("Combo X")
@export var combo_window := 0.6

@export_group("X cargado (dash sweet spot)")
@export var charged_dash_distance := 5.0
@export var charged_dash_duration := 0.14

@export_group("Y cargada aérea (spike + rebote)")
## Velocidad del spike hacia el suelo antes de rebotar. La altura del auto-launch y del
## rebote reusan el launcher Y (height/hang_time), "lo mismo que un launcher".
@export var aerial_charged_down_speed := 30.0

@export_group("Launcher Y")
@export var launcher_height := 4.0
@export var launcher_hang_time := 1.0
@export var launcher_hitbox_duration := 0.18
@export var launcher_deals_damage := true
