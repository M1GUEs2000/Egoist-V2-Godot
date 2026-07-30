---
title: Contrato AttackClip
tags:
  - egoist
  - decisiones
  - combate
  - animacion
status: active
system_status: E1
hito: H1
---

# Contrato AttackClip

Superficie congelada entre los dos trabajos que corrieron en paralelo sobre el sistema de ataques. **Ninguno de los dos lados edita este contrato sin avisar al otro**: si cambia un campo se rompen los dos a la vez y en silencio, porque los `.tres` serializan por nombre. *(2026-07-30)*

> [!success] Los dos trabajos aterrizaron
> **A (animador)** en `feat/animador`, **B (secuenciador)** en `main`, integrados el 2026-07-30. Los dos escribieron `data/attack_clip.gd` por separado y las dos versiones declararon los mismos campos, tipos y defaults: el contrato aguanto. Se conservo la de B, que ademas trae `open_seconds()` / `open_delay()`.
>
> Falta el **empalme**, que no era de ninguno de los dos: ver "Lo que falta" abajo.

## Por que existe

Hoy el Player tiene **dos espadas**. La que se ve cuelga del hueso de la mano por `BoneAttachment3D` y sigue la animacion. La que golpea es invisible, orbita al Player y la mueven tweens procedurales (`_play_swing`, `_play_spin`, `thrust` en `WeaponBase`). Nunca coincidieron: el swing procedural es una aproximacion del clip. Ademas la ventana de daño dura **todo** el swing en vez de abrirse en el momento del impacto.

El objetivo es que el hitbox cuelgue del hueso y que su apertura sea un dato del clip. Eso parte el trabajo en dos mitades que no se tocan.

## Los dos trabajos

| | Trabajo A — Animador | Trabajo B — Secuenciador |
|---|---|---|
| Dueño de | `player/player_animation_controller.gd`, `combat/hitbox.gd`, escenas `.tscn` de armas, `combat/attack_clip_player.gd` | `combat/weapons/`, `data/attack_step.gd`, `attack_branch.gd`, `attack_sequence.gd`, tunings de armas |
| Entrega | el hitbox colgado del hueso y un componente que reproduce un tramo de clip avisando cuando abre y cierra | los `AttackStep` / `AttackSequence`, el runner con **una ventana de daño por paso**, y los combos migrados a datos |
| No toca | nada de `combat/weapons/` ni ningun tuning | nada de `player/` ni el hitbox ni las escenas de armas |

`data/attack_clip.gd` es el unico archivo que los dos leen.

## El contrato

```gdscript
class_name AttackClip extends Resource
    @export var clip: StringName        # nombre en el AnimationPlayer
    @export var start_time := 0.0       # segundo del clip donde arranca el tramo
    @export var end_time := -1.0        # -1 = hasta el final
    @export var duration := 0.0         # segundos REALES del golpe; 0 = velocidad natural
    @export_range(0.0, 1.0) var hitbox_open := 0.0
    @export_range(0.0, 1.0) var hitbox_close := 1.0

# combat/attack_clip_player.gd (Trabajo A):
signal hitbox_should_open
signal hitbox_should_close
signal clip_finished
func play_attack_clip(c: AttackClip) -> void
func cancel() -> void
```

Dos decisiones que no son arbitrarias:

- **`hitbox_open` / `hitbox_close` van normalizados 0-1** sobre `duration`, no en segundos. Cambiar cuanto dura el golpe no tiene que invalidar la ventana de daño.
- **`start_time` / `end_time` / `duration` van en SEGUNDOS, no en frames.** Es 3D con esqueleto UAL y el `AnimationPlayer` de Godot trabaja en segundos. Traducir a frames seria inventar una unidad que el motor no tiene.

El componente **no** decide daño, no abre hitboxes por su cuenta y no sabe que arma lo usa: reproduce el tramo y avisa. Quien conecta esas señales a una ventana de daño es el secuenciador.

## Lo que falta (el empalme)

Cada mitad hace lo suyo pero todavia no se hablan. Hoy el camino es:

`run_attack_sequence` → `play_visual_clip(clip, start, end, duration)` → señal `visual_clip_started` → `PlayerAnimationController` **reconstruye** un `AttackClip` → `AttackClipPlayer`.

Ese round-trip pierde `hitbox_open` y `hitbox_close`: el controller arma el clip con los defaults 0 y 1, asi que la ventana de daño **sigue durando todo el golpe** y sigue abriendola `begin_damage_window` por temporizador. Lo que queda:

1. Que el `AttackClip` viaje entero en vez de reconstruirse — señal que lleve el Resource, no cuatro floats.
2. Conectar `hitbox_should_open` / `hitbox_should_close` a `Hitbox.begin_swing()` / `end_swing()` y sacarle a `begin_damage_window` la parte de abrir el hitbox (los ganchos de perfil de movimiento se quedan donde estan).
3. Borrar el swing procedural de `WeaponBase`: `swing`, `swing_up`, `_swing_axis`, `thrust`, `_set_thrust_progress`, `_play_swing`, `_play_spin`, `_set_spin_angle`, `_hand_rest`, `_set_hand_radius`, `_reset_hand`, `_kill_swing_tween`, su llamada desde `_ready()` y el estado asociado. Con eso muere tambien `AttackStep.choreography` y el `match` de `Sword.on_sequence_step`.
4. Recien ahi entra el **RT attack sequence**.

Mientras tanto el swing procedural sigue vivo pero mueve un `Hand/Pivot` **vacio**: no mueve ni el arma visible ni su hitbox. Es inofensivo, no un bug.

## Lo que cuesta

Cuando A y B se junten, **ningun valor de tuning de Espada ni de Mazo sirve**: el arma real deja de estar donde estaba, asi que alcance, timing, `hand_radius`, `strike_angle` y `push_at` se re-tunean todos a mano jugando. No es un bug del refactor, es su precio, y esta aceptado. Ver [[Metodologia V2]] para el ciclo E0-E4.

## Relacionado

- [[Armas]]
- [[Espada]]
- [[Mover y Floater]]
- [[Animacion]]
