---
title: Dash y Airdash
tags:
  - egoist
  - gameplay
  - sistema
  - traversal
status: active
system_status: E2
hito: H1
---

# Dash y Airdash

Dash defensivo/ofensivo y su variante aerea. Implementado en `PlayerDash`.

## Reglas actuales

- **Dodge:** choca con enemigos y objetos, no los traspasa. *(2026-07-06)*
- Si hay barra, el dodge puede hacer dano, pero no aplica stun; el stun del dash normal es 0 en suelo y aire. *(2026-07-07)*
- **Dash ofensivo** (`PlayerDash.force_dash`, ej. el X cargado de la espada): atraviesa enemigos y choca con objetos.
- La diferencia es el flag `pass_through_enemies` en `_start_dash`: solo el ofensivo quita la capa `enemy` del `collision_mask`.

## World switch

> [!important]
> Dodge no cambia mundo automaticamente. Dodge puede disparar switch solo si una maldicion/bonus lo modifico.

El cambio de mundo vive en [[World Switch]], no en dash por defecto.

## Relacionado

- [[Movimiento Base]]
- [[World Switch]]
- [[Combate]]
- [[Traversal]]
