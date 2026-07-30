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

> [!success] Cerrado
> **A (animador)** y **B (secuenciador)** aterrizaron y estan empalmados (2026-07-30). Los dos escribieron `data/attack_clip.gd` por separado y las dos versiones declararon los mismos campos, tipos y defaults: el contrato aguanto. Se conservo la de B, que ademas trae `open_seconds()` / `open_delay()`.
>
> El swing procedural **ya no existe**. Ver "Como quedo" abajo.

## Por que existe

Hoy el Player tiene **dos espadas**. La que se ve cuelga del hueso de la mano por `BoneAttachment3D` y sigue la animacion. La que golpea es invisible, orbita al Player y la mueven tweens procedurales (`_play_swing`, `_play_spin`, `thrust` en `WeaponBase`). Nunca coincidieron: el swing procedural es una aproximacion del clip. Ademas la ventana de daño dura **todo** el swing en vez de abrirse en el momento del impacto.

El objetivo es que el hitbox cuelgue del hueso y que su apertura sea un dato del clip. Eso parte el trabajo en dos mitades que no se tocan.

## Los dos trabajos

| | Trabajo A — Animador | Trabajo B — Secuenciador |
|---|---|---|
| Dueño de | `player/player_animation_controller.gd`, `combat/hitbox.gd`, escenas `.tscn` de armas, `combat/attack_clip_player.gd` | `combat/weapons/`, `data/attack_step.gd`, `attack_sequence.gd`, tunings de armas |
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

## Como quedo el empalme

El `AttackClip` viaja **entero**. `visual_clip_started` pasa a llevar el Resource en vez de cuatro floats sueltos, y `PlayerAnimationController` se lo entrega tal cual a `AttackClipPlayer` en vez de reconstruir uno (que era donde se perdian `hitbox_open` y `hitbox_close`).

Camino completo de un golpe de combo:

```
run_attack_sequence
  → _begin_sequence_step
      → play_attack_clip(step.clip, duration)   ── dibujo ──→ AttackClipPlayer
      → begin_damage_window(duration, ..., step.clip)  ── daño
```

Las dos ramas leen **el mismo Resource**: el clip dice que tramo se ve, y el mismo clip dice en que fraccion de ese tramo el hitbox esta abierto.

### La ventana de daño no viene por señal

`AttackClipPlayer` nacio con `hitbox_should_open` / `hitbox_should_close` para que el arma colgara su ventana de la animacion. **Se quitaron.** Tres razones:

1. La ventana la tiene que abrir el arma igual, porque los especiales todavia no tienen `AttackClip` y no pasan por el reproductor. Serian dos caminos para lo mismo.
2. `play_attack_clip` emite la apertura **en el acto** cuando `hitbox_open` es 0, que es el caso normal. El arma no llega a conectarse: se perderia el golpe entero. Race real, no teorica.
3. El reproductor es uno solo, colgado del Player, y no sabe que arma pidio el clip.

Los dos relojes son el mismo reloj: los dos cuentan los segundos de `duration`. `begin_damage_window` espera `open_delay(duration)`, abre, espera `open_seconds(duration)`, cierra, y espera el sobrante hasta completar el golpe — el gesto siempre dura lo mismo aunque el hitbox cierre antes, porque el recorrido `WINDOW_END` del perfil marca el fin del GESTO, no el fin del daño.

### Lo que se borro

Las doce funciones del swing procedural (`swing`, `swing_up`, `_swing_axis`, `thrust`, `_set_thrust_progress`, `_play_swing`, `_play_spin`, `_set_spin_angle`, `_hand_rest`, `_set_hand_radius`, `_reset_hand`, `_kill_swing_tween`), su estado, y todo el tuning que solo existia para alimentarlas: el grupo **Mano** entero de `WeaponTuning` (`hand_height`, `hand_radius`, `hand_rest_yaw`), y de las armas `strike_angle`, `combo_swing_angle`, `thrust_reach`, `air_diagonal_yaw`, `air_diagonal_pitch`, `air_finisher_angle`, `charged_fallback_angle`, `smash_angle`, `air_handle_reach`.

`AttackStep.choreography` **sobrevive** pero cambio de significado: ya no nombra un tween, nombra una FAMILIA de golpe para las mecanicas que no son dato (sostener al Player en el aire durante el combo terrestre, estirar los hitboxes en V del finisher aereo).

> [!warning] El combo aereo del Mazo era el unico gesto sin clip
> Su dibujo salia entero de los tweens, asi que al borrarlos se quedaba sin animacion. Reusa por ahora los dos tramos del combo terrestre como placeholder: se ve como un combo terrestre en el aire. El Mazo esta en E2 y su set aereo propio no existe. Ver `Mace._begin_air_step`.

`Hand/Pivot` sigue en las escenas de armas: quedo como percha de lo que se crea en runtime (las motas de sweet spot), que el controller tambien reparenta al hueso.

## Lo que cuesta

Cuando A y B se junten, **ningun valor de tuning de Espada ni de Mazo sirve**: el arma real deja de estar donde estaba, asi que alcance, timing, `hand_radius`, `strike_angle` y `push_at` se re-tunean todos a mano jugando. No es un bug del refactor, es su precio, y esta aceptado. Ver [[Metodologia V2]] para el ciclo E0-E4.

## Relacionado

- [[Armas]]
- [[Espada]]
- [[Mover y Floater]]
- [[Animacion]]
