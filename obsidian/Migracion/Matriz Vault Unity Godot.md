---
title: Matriz Vault Unity Godot
tags:
  - egoist
  - migracion
  - godot
status: active
hito: H0
---

# Matriz Vault Unity Godot

Esta tabla resume como se migra la verdad vieja a Godot V2.

| Sistema | Vault vieja | Unity V1 | Godot V2 | Estado | Decision |
|---|---|---|---|---|---|
| Mundos duales | [[Traversal]] | `WorldManager`, `WorldMembership`, `WorldSwitchTrigger` | `WorldManager`, `WorldMembership`, `WorldSwitchTrigger` | E2 | Switch por triggers, no dodge gratis. |
| Player movimiento | [[Traversal]] | `PlayerController`, `PlayerMotor`, `PlayerLocomotion`, `PlayerDash`, `PlayerLauncher` | `Player`, `PlayerLocomotion`, `PlayerDash`, `PlayerLauncher`, `PlayerWallSlide`, `PlayerEnemyBounce` | E1 | `CharacterBody3D` reemplaza `CharacterController`; momentum y rebote en enemigos pendientes de validar jugando. |
| Player meter | [[Combate]] | `PlayerMeter`, `MeterHUD` | `PlayerMeter`, HUD escucha senales | E2 | Base implementada; mejoras a 5 barras son futuro. |
| Combate base | [[Combate]] | `Health`, `IHittable`, `WeaponTraceHitbox`, `AirDiscHitbox` | `Health`, `Hurtbox`, `Hitbox`, `WeaponBase` | E2 | Grupos y duck typing reemplazan interfaces. |
| Espada | [[Armas]] / [[Combate]] | `SwordWeapon`, behaviours X/Y | `Sword`, `SwordTuning` | E2 | Procedural hasta H3. |
| Enemigo de suelo | [[Enemigos]] | `EnemyBase`, `GroundedEnemy` | `EnemyBase`, `GroundedEnemy` | E2 | Un enemigo base componible. |
| IA | [[IA]] | Unity Behavior Tree | LimboAI (BT + HSM) + blackboard | E2 | Backend unico; el enum `AIState` sobrevive como catalogo. |
| HUD | [[Combate]] | HUD Unity descartable | `HUD` | E1 | Placeholder; rehacer H1. |
| Lock-on | [[Combate]] | `LockOnTargeting` | `LockOn` | E3 | Implementado: adquisicion por direccion, reticle, integracion con locomocion. |
| Cadenas | [[Traversal]] | `PlayerSwing`, `ChainSwingHandle` | `PlayerSwing` stub | E0 | Implementar en H1. |
| Visual mundos | [[Areas]] / [[Traversal]] | `WorldVisualController` | `WorldVisual` stub | E0 | Implementar 2 ambientes + lerp. |
| Indicador aterrizaje | [[Traversal]] | `LandingIndicator` | `LandingIndicator` | E3 | Implementado: raycast, orientacion por normal. |
| Animacion | [[Animacion]] | Animator Humanoid/Mixamo | Retarget Godot pendiente | E0 | Placeholder primero, animacion real H3. |
| Arte Blender | [[Blender Pipeline]] | FBX/URP | GLB/FBX + materiales Godot | Pendiente | No arte final antes de H3. |

## Contradicciones resueltas

> [!warning] Dodge y world switch
> La boveda vieja conserva una decision congelada antigua: `Dodge = world switch`. La decision actual para V2 es: dodge es movilidad; el world switch se dispara por triggers ganados o acciones modificadas.

> [!warning] Unity-first
> Referencias a `ScriptableObject`, `MonoBehaviour`, `CharacterController`, `BehaviorGraph`, `Animator Controller` y `Shader Graph URP` son historicas. En V2 se traducen a patrones Godot.

## Relacionado

- [[Arquitectura Godot]]
- [[Decisiones Congeladas]]
- [[hitos]]
