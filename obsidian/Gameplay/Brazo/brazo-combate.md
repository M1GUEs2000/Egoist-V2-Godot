---
title: Brazo Combate
aliases:
  - brazo-combate
  - Brazo Combate
tags:
  - egoist
  - gameplay
  - combate
  - brazo
status: active
system_status: E3
hito: H2
---

# Brazo Combate

Uso del [[Brazo]] dentro del combate. Su funcion no es hacer de arma nueva, sino aumentar el kit que ya existe: mas control, mas opciones de aire y un boton para recuperar lectura cuando la pelea esta rapida o caotica.

## Implementado en Godot

`player/player_arm.gd` (`PlayerArm`) + `data/arm_tuning.gd` (`ArmTuning`, instancia
`arm_tuning.tres`). Un tap (`arm_attack`) pega al target del lock-on pasivo: lockeado si hay uno
(mismo [[Lock On]] de combos), si no el enemigo mas centrado en el cono de mira (mismo target que
usa el snap del golpe normal sin lock). Daño y poise bajos (`damage`, `stun` en `ArmTuning`);
genera meter propio al conectar (`meter_gain_on_hit`). `max_taps` seguidos antes de forzar
`cooldown_duration` segundos de bloqueo.

**Reaccion aerea propia** (si el tap conecta con el jugador en el aire): mas corta que el hang del
combo aereo de la Espada. Dos efectos separados, ambos en `arm_tuning.tres`:

- **Vertical → Floater**: `Player.register_arm_air_hit` arranca un Floater con el perfil
  `air_hang_floater` (un `FloaterSettings`: `duration` 0.1, `fall_scale` 0 = hold total). Mismo
  primitivo que cualquier otro ataque (ver [[Plan Autoridad Vertical]]), no un sistema propio del
  brazo. Al terminar la ventana la caida arranca de 0 (se lee como "hang", no como "pausa").
- **Horizontal → freno que decrece**: el momentum `bump` se **decelera** en el acto por
  `air_horizontal_keep` (0-1; 0.5 = lo parte a la mitad cada golpe, 1.0 = no frena, 0.0 = lo mata).
  No es pausa: cada golpe encadenado lo baja mas.

Ambos knobs viven en `ArmTuning` (propios del Brazo, no comparten los del arma) y estan pendientes
de tunear jugando. El resto de esta nota (brazo cargado, sostenimiento aereo con agarre del
enemigo, golpe a objetos) es diseño a futuro, todavia no implementado.

## Intencion

El brazo permite mandar un puño remoto hacia el objetivo marcado por un lock-on pasivo. Ese golpe puede mantener enemigos un poco en el aire, reposicionarlos o sostenerlos el tiempo suficiente para que el jugador respire y decida el siguiente movimiento.

Debe apoyar los combos de armas sin robarles identidad:

- La [[Espada]] mantiene el flujo base.
- El [[Mazo]] controla masas y empuja fuerte.
- Las [[Dagas]] seran movilidad/persecucion.
- Los [[Punos]] seran agarre como arma H2.
- El brazo es transversal: siempre esta disponible.

## Lock-on del brazo

Distinto al [[Lock On]] de combos.

| Lock-on | Funcion |
|---|---|
| Lock-on de combos | Ayuda a orientar ataques de arma y alimentar `attack_step` hacia el objetivo. |
| Lock-on del brazo | Marca pasivamente hacia donde mira/apunta el jugador, sin moverlo hacia el objetivo. |

Regla importante: activar el brazo no debe disparar el avance de combo. El jugador puede moverse libremente mientras el objetivo del brazo queda marcado.

## Acciones posibles

| Accion | Idea |
|---|---|
| Tap de brazo | Puño remoto pega al objetivo marcado. Control ligero, poco o ningun costo. |
| Brazo cargado | Atrae o sostiene lo golpeado. Puede costar meter. |
| Golpe a enemigo aereo | Mantiene al enemigo suspendido un poco mas, para continuar combo o reposicionarse. |
| Golpe a objeto | Activa o atrae objetos golpeables si el sistema lo permite. |

## Rol de feel

El brazo existe para dar respiracion:

- Cortar la sensacion de caos sin pausar el combate.
- Dar un micro-momento de control cuando hay varios enemigos.
- Mantener el aire vivo sin convertir todos los ataques en launcher.
- Dar una opcion defensiva/neutral que no sea dodge ni arma.

## Restricciones

- No ocupa slot X/Y.
- No aparece en el loadout como arma.
- No hereda de `WeaponBase`.
- No debe invalidar el rol de [[Punos]] como arma de agarre.
- No debe volver trivial el juggle infinito: necesita cooldown, costo, limite de aire o decay.

## Preguntas de diseno

- Cuanto tiempo sostiene a un enemigo en aire.
- Si el sostenimiento escala con peso/tamano/armadura.
- Si enemigos armored pueden ignorarlo, resistirlo o consumir mas meter.
- Si el brazo rompe, extiende o pausa el combo global.
- Si puede fallar por rango o si siempre llega al target marcado.

## Relacionado

- [[Brazo]]
- [[Combate]]
- [[Lock On]]
- [[Meter]]
- [[Punos]]
