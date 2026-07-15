---
title: Hostilidad
tags:
  - egoist
  - enemigo
  - ia
status: active
system_status: E2
hito: H1
---

# Hostilidad

Hostilidad define la intencion del enemigo: quien inicia combate, que significa buscar y cuando huye. El sensor y el arbol de decision viven en [[IA]] (catalogo comun `AIState` + `allowed_state_flags`); la identidad del enemigo vive aqui.

| Valor Godot | Comportamiento | Detalle |
|---|---|---|
| `PASSIVE` | No inicia combate solo por ver al jugador; si lo atacan, puede reaccionar (toggle `passive_remembers_attackers`). Su `SEARCH` es investigacion/curiosidad. | [[Pasivo]] |
| `REACTIVE` | Defiende territorio: ataca si el jugador entra demasiado cerca o invade su zona. Su `SEARCH` busca al intruso. | [[Reactivo]] |
| `AGGRESSIVE` | Inicia conflicto contra el jugador, pasivos, reactivos y ultras; nunca dana a otro agresivo. Su `SEARCH` intenta recuperar al objetivo perdido. | [[Agresivo]] |
| `ULTRA_AGGRESSIVE` | Berserker: ataca cualquier objetivo valido y puede cambiar a uno mejor si aparece. No usa `FLEE`, `HIDE`, `GUARD` ni `ATTACK_GROUP`; su actividad idle se limita a dormir o comer presas. | [[Ultra Agresivo]] |

Cada nota de detalle documenta el comportamiento especifico de ese nivel con referencias directas al codigo (que metodo produce que estado, con que valores). Esta nota es el resumen; el detalle vive ahi. *(2026-07-08)*

## Deteccion y memoria

Nadie es omnisciente: todos detectan por rango + angulo + raycast (ver [[IA]]). La memoria del target crece con la hostilidad: pasivo `10s`, reactivo `20s`, agresivo `40s`, ultra agresivo `60s`.

## Huida

Al cruzar 30% de vida hay una tirada unica de `FLEE`: pasivo `0.50`, reactivo `0.25`, agresivo `0.05`, ultra agresivo `0.0`. `HIDE` solo ocurre despues de `FLEE`.

## Autodefensa

- Un pasivo golpeado se provoca (`EnemyBase` delega en `_on_passive_attacked`).
- Puede despertar pasivos cercanos por `alert_radius`.
- En H2, esto puede depender de mascara/cordura.

## Alianzas y dano

La hostilidad es una identidad estable para el dano; la alerta temporal de un pasivo provocado no lo convierte en agresivo. Todos conservan la colision fisica entre cuerpos; esta tabla solo decide dano, stun y reacciones de impacto.

| Atacante \ Victima | Pasivo | Reactivo | Agresivo | Ultra agresivo |
|---|---:|---:|---:|---:|
| Pasivo | No | No | Si | Si |
| Reactivo | No | No | Si | Si |
| Agresivo | Si | Si | No | Si |
| Ultra agresivo | Si | Si | Si | Si |

- Los agresivos son quienes inician los conflictos normales contra pasivos y reactivos.
- Al recibir dano permitido, pasivos, reactivos y agresivos fijan temporalmente al atacante como objetivo y pueden responder.
- El ultra agresivo no tiene aliados: puede iniciar contra cualquier objetivo valido.

## Relacionado

- [[Mascaras y Cordura]]
- [[IA]]
- [[Ecosistema Vivo]]
