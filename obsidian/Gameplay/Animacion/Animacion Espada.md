---
title: Animacion Espada
tags:
  - egoist
  - gameplay
  - animacion
  - combate
status: active
system_status: E1
hito: H1
---

# Animacion Espada

Clips UAL para el combate de [[Espada]] sobre el player. Implementado: `sword.gd` emite `visual_clip_started` (señal de `WeaponBase.play_visual_clip`) al arrancar cada golpe y `PlayerAnimationController` reproduce el tramo en el maniqui, escalado a la duracion mecanica del golpe (`swing_time` / `charged_dash_duration`). Los swings por quaternion en `Hand` siguen siendo el motor de hitboxes: la animacion es solo visual. Ver [[Player]] para locomocion/salto/slide.

Clips en `assets/animations/Universal Animation Library 2[Standard]/.../Unreal-Godot/UAL2_Standard.glb`, nombres verificados contra el JSON del `.glb` (no inventados).

## Clips usados

| Clip | Duración |
|---|---|
| `Sword_Regular_A` | 0.433 s |
| `Sword_Regular_B` | 0.533 s |
| `Sword_Regular_C` | 2.00 s |
| `Sword_Dash` | 1.567 s |
| `Sword_Heavy_Combo` | 4.333 s (se usa por tramos) |

> [!warning]
> `Sword_Regular_A_Rec` / `Sword_Regular_B_Rec` (clips de recuperación) existen en UAL2 pero no están pedidos en este plan — quedan disponibles si el combo terrestre necesita un respiro entre golpes mas adelante.

## Combo terrestre (tap)

Motor: `run_combo_chain` en `sword.gd`, combo de 4 pasos con rama de espera en los pasos 3-4 (ver [[Espada]] para la descripción de diseño: swing, swing, estocada/vuelta).

| Input | Secuencia de clips |
|---|---|
| Tap tap tap tap (sin espera) | `Sword_Regular_A`, `Sword_Regular_B`, `Sword_Regular_A`, `Sword_Regular_B` |
| Tap tap (espera) tap tap | `Sword_Regular_A`, `Sword_Regular_B`, `Sword_Regular_C`, `Sword_Regular_C` |

## Combo aereo (tap)

Espejo del terrestre: diagonales con A/B, vueltas de la rama espera con C y el hachazo vertical con el mismo tramo aereo de `Sword_Heavy_Combo` que la Y cargada.

| Input | Secuencia de clips |
|---|---|
| X X X (sin espera) | `Sword_Regular_A`, `Sword_Regular_B`, `Sword_Heavy_Combo` 2.40-2.70 s |
| X (espera) X X | `Sword_Regular_A`, `Sword_Regular_C`, `Sword_Regular_C` |
| X X (espera) X (plunge) | Mismos clips que X X X: el plunge reusa el hachazo (`Sword_Heavy_Combo` 2.40-2.70 s), sin clip propio. |

## Cargados

| Move | Clip / tramo |
|---|---|
| X cargado (piso y aire — dash ofensivo) | `Sword_Dash` completo |
| Y cargado en piso (launcher) | `Sword_Heavy_Combo` de 0.90 a 1.30 s |
| Y cargado en aire | `Sword_Heavy_Combo` de 2.40 a 2.70 s |

## Estela de la hoja

El arco que deja la hoja al golpear tiene nodo propio: [[Trail]]. Lo que importa desde acá es que la
estela **sale del hueso `hand_r`**, o sea del mismo clip que reproduce este documento, y que la
prende y apaga la ventana de daño del golpe — no hay un segundo lugar donde el arco pueda
desincronizarse de la animación.

## H3

Cambiar la estela procedural por una **slash card**: mesh de arco autorado con UV espejada y textura
channel-packed, compuesta en capas base / highlight / support.

Es el intercambio inverso al de hoy, y ninguno de los dos es mejor en abstracto:

| | Estela procedural (hoy, H1) | Slash card (H3) |
|---|---|---|
| De donde sale la forma | El recorrido real del hueso | Un mesh autorado |
| Alineacion con la animacion | Gratis, es la animacion misma | **A mano**, golpe por golpe |
| Libertad para dirigir el corte | Ninguna: si la animacion es fea, la estela es fea | Total, no queda atada al arma |
| Coste de un gesto nuevo | Cero | Autorar y alinear |

Espera a H3 a proposito: la card recien se paga cuando existan los ataques de Espada hechos en
Blender y haya animacion final que valga la pena alinear. Antes de eso la sincronia vale mas que el
control, con cuatro gestos por dos tramos y el dano ya saliendo del `AttackClip`.

De las capas del marco, la que mas se nota y hoy **no existe** es el **highlight**: mas chico que la
base, mas brillante y con el taper agresivo que corresponde a una espada (el Mazo pediria uno romo).
Sobre lo que ya esta es una segunda tira mas delgada con su propio gradiente. El `base_fade` del
tuning de hoy es un sustituto pobre de esa capa. La capa de **impacto** ya tiene donde vivir:
`VfxInjector.spawn_impact`, que `WeaponBase` llama al conectar.

## Relacionado

- [[Player]]
- [[Animacion]]
- [[Espada]]
- [[Combate]]
- [[Animacion Mazo]]
