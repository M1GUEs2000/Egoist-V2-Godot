---
title: Dash y Airdash
tags:
  - egoist
  - gameplay
  - sistema
  - traversal
status: active
system_status: E3
hito: H1
---

# Dash y Airdash

Dash defensivo/ofensivo y su variante aerea. Implementado en `PlayerDash`.

## Reglas actuales

- **Dodge:** choca con enemigos y objetos, no los traspasa. *(2026-07-06)*
- Si hay barra, el dodge puede hacer dano, pero no aplica stun; el stun del dash normal es 0 en suelo y aire. *(2026-07-07)*
- **Dash ofensivo** (`PlayerDash.force_dash`, ej. el X cargado de la espada): atraviesa enemigos y choca con objetos.
- La diferencia es el flag `pass_through_enemies` en `_start_dash`: solo el ofensivo quita la capa `enemy` del `collision_mask`.
- **Particulas brillantes:** emisor `DashParticles` (`GPUParticles3D`, hijo de `Dash`) que `PlayerDash` prende en `_start_dash` y apaga en `_end_dash`. El color NO se hardcodea: se pinta desde `World.COLOR_TRAVERSAL_DASH` en `_tint_particles_from_world` (ver [[Colores de mundo]]); el material del `.tscn` es solo preview. El bloom lo da el `WorldEnvironment` con glow. Look tuneable en el `ParticleProcessMaterial`. *(2026-07-10)*

## World switch

> [!important]
> Dodge no cambia mundo automaticamente. Dodge puede disparar switch solo si una maldicion/bonus lo modifico.

El cambio de mundo vive en [[World Switch]], no en dash por defecto.

## Relacionado

- [[Movimiento Base]]
- [[World Switch]]
- [[Combate]]
- [[Traversal]]
