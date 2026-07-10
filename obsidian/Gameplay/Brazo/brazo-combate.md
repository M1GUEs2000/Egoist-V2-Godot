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
status: planned
system_status: E0
hito: H2
---

# Brazo Combate

Uso del [[Brazo]] dentro del combate. Su funcion no es hacer de arma nueva, sino aumentar el kit que ya existe: mas control, mas opciones de aire y un boton para recuperar lectura cuando la pelea esta rapida o caotica.

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
