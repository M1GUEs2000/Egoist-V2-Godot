---
title: Mazo
aliases:
  - Morningstar
tags:
  - egoist
  - gameplay
  - arma
status: planned
hito: H2
---

# Mazo / Morningstar

Arma de mas dano. Controla masas. Tiene bastante knockback. Tumba a los enemigos. Velocidad lenta.

## Terrestre

| Input | Descripcion |
|---|---|
| X X X | Swing horizontal, swing horizontal, smash vertical con AOE. |
| X X espera X X | Swing horizontal, swing horizontal, tres smash verticales. Todos con AOE. |
| X cargado (3 niveles) | Das vueltas y golpeas. 1 carga = 1 vuelta, 2 cargas = 2 vueltas, 3 cargas = 3 vueltas. |
| X cargado sweet spot | Los enemigos que pega quedan congelados hasta la ultima vuelta. |
| Y cargado | Launcher omnidireccional. Area grande. |
| Y cargado sweet spot | Hace dos golpes para subirlos al aire. |

## Aereo

| Input | Descripcion |
|---|---|
| X | Ataque con knockback hacia adelante. |
| X cargado | Caes con un ataque AOE. |
| X cargado sweet spot | Caes con un ataque y al final das una vuelta. Los mantiene en el aire. |
| Y cargado | Das vueltas y botas todo hacia los lados. |
| Y cargado sweet spot | Los mantiene en el aire como congelados. A ti tambien te da mas tiempo airborne. |

## Estado Godot

- Placeholder implementado *(2026-07-07)*: `combat/weapons/mace/mace.gd` define `Mace`, que **hereda de `Sword`** y reutiliza su comportamiento completo. No tiene combos propios todavia; es un arma de prueba para el loadout X/Y, no una familia de combos nueva.
- `mace.tscn`: visual de palo con bola al final; mantiene los nombres de hitboxes que espera `Sword` (`Pivot/BladeHitbox`, `AirDiscHitbox`, `LauncherHitbox`, `ChargedDashHitbox`).
- Instanciado como hijo del player en `player.tscn`; `PlayerCombat` solo muestra las armas asignadas a slots.
- Los combos propios de la tabla de arriba entran despues de cerrar H1 con [[Espada]].

## Relacionado

- [[Armas]]
- [[Combate]]

