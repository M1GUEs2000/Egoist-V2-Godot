---
title: Arquitectura Godot
tags:
  - egoist
  - godot
  - arquitectura
  - sistema
status: active
system_status: E2
hito: H0
---

# Arquitectura Godot

Godot V2 es la version activa. Unity V1 solo se usa como referencia de comportamiento cuando una mecanica no este clara.

## Stack

| Elemento | Valor |
|---|---|
| Motor | Godot 4.7 |
| Render | Forward Plus |
| Fisica | Jolt Physics |
| Lenguaje | GDScript tipado estatico |
| Entrada | `[input]` en `project.godot` |
| Camara | `CameraRig`, pitch 30, yaw 45, distance 18 |
| Datos tuneables | `Resource` + `.tres` en `data/` |
| Integracion IA | LimboAI v1.1.1 instalado en `addons/limboai/`; port pendiente desde FSM actual |

## Estructura real

```text
autoload/   WorldManager, GameManager, ComboTracker
core/       World, WorldMembership, WorldSwitchTrigger, ActionWorldSwitchModifier
combat/     Health, Hurtbox, Hitbox, InputBuffer, weapons/
data/       PlayerTuning, SwordTuning, WeaponTuning, StunSettings, PushSettings, GameTuning
player/     Player glue + Locomotion, Dash, Launcher, Meter, Combat, LockOn, Swing, WallSlide, EnemyBounce, Stun
enemies/    EnemyBase, GroundedEnemy, Perception, GroundLocomotion, attacks/
ui/         HUD, ActionLoadoutMenu
visual/     CameraRig, CameraOcclusionFade, WorldVisual, LandingIndicator
world/      test_scene, smoke_test, wall_slide_probe, blocks, pickups
obsidian/   esta boveda
```

## Estructura de la boveda

> [!important] Mapa maestro
> Cada nodo grande vive como carpeta con una nota indice del mismo nombre. Las subnotas viven dentro de esa carpeta. Usar wikilinks simples por nombre, no rutas, para que Obsidian pueda mover notas sin romper enlaces.

```text
obsidian/
  README.md
  Arquitectura Godot.md
  Metodologia V2.md
  Gameplay/
    Combate/Combate.md
    Traversal/Traversal.md
    Enemigos/Enemigos.md
    IA/IA.md
    Armas/Armas.md
    Areas/Areas.md
    Historia/Historia.md
    Exploracion/Exploracion.md
    Animacion/Animacion.md
  Tareas/
  Decisiones/
  Arte/
  Migracion/
  Bases/
```

## Indice de nodos de gameplay

| Nodo | Carpeta | Subnotas registradas |
|---|---|---|
| [[Combate]] | `Gameplay/Combate/` | [[Meter]], [[Input Feel]], [[Lock On]] |
| [[Traversal]] | `Gameplay/Traversal/` | [[Movimiento Base]], [[Dash y Airdash]], [[Launcher y Aire]], [[Momentum y Bump]], [[Wall Slide y Wall Jump]], [[Rebote en Enemigos]], [[World Switch]], [[Bloques]], [[Cadenas]], [[Occlusion Fade de Camara]], [[Landing Indicator]], [[Colores de mundo]] |
| [[Enemigos]] | `Gameplay/Enemigos/` | [[Modelo de Enemigo]], [[Mascaras y Cordura]], [[Hostilidad]], [[Afiliacion de Mundo]], [[Estados de Combate Enemigo]], [[Ataques Enemigos]], [[Ecosistema Vivo]], [[Objetos Golpeables]], [[Roster Enemigos]], [[Melee Living]], [[Ranged Dead]], [[Armored Enemy]], [[Jefes]] |
| [[IA]] | `Gameplay/IA/` | Indice de FSM, percepcion, locomocion y ataques. |
| [[Armas]] | `Gameplay/Armas/` | [[Espada]], [[Mazo]], [[Dagas]], [[Punos]] |
| [[Areas]] | `Gameplay/Areas/` | [[Playa]], [[Castillo]], [[Averno]], [[Final]] |
| [[Historia]] | `Gameplay/Historia/` | Lore, mascaras, NPCs y final. |
| [[Exploracion]] | `Gameplay/Exploracion/` | Runas, consumibles, secretos y rutas opcionales. |
| [[Animacion]] | `Gameplay/Animacion/` | Retarget Godot y animacion H3. |

## Registro del roster de armas

> [!warning]
> Roster definitivo segun `Boveda/Gameplay/Armas/Armas.md`: [[Espada]], [[Mazo]], [[Dagas]] y [[Punos]]. No usar Hachas, Capa, Guantes, Ruedarang ni Latigo como armas activas de V2.

## Patrones obligatorios

| Problema | Patron Godot |
|---|---|
| Estado global fino | Autoload sin logica pesada (`WorldManager`) |
| Comportamiento componible | Nodo hijo con `setup(body)` |
| Datos tuneables | Resource `.gd` + instancia `.tres` |
| Eventos | Senales tipadas |
| Contratos opcionales | `has_method()` + grupos |
| Golpeables | `Hitbox`/`Hurtbox`, grupo `hurtbox`, no interfaces C# |
| UI | `CanvasLayer`/Control que escucha senales |
| Tuneables legibles | Todo `@export` de tuning lleva comentario `##` encima (tooltip en el inspector: que hace, unidades, efecto) |

## Mapa Unity V1 a Godot V2

| Unity V1 | Godot V2 |
|---|---|
| Singleton lazy C# | Autoload |
| Eventos C# | Senales |
| `CharacterController` + `PlayerMotor` | `CharacterBody3D.velocity` + `move_and_slide()` |
| `IHittable` | `Hurtbox` + grupo |
| `ILaunchable`, `IParryable` | `has_method("launch")`, `has_method("try_parry")` |
| `ScriptableObject` | `Resource` `.tres` |
| `TestSceneBuilder.cs` | Escenas `.tscn` editadas directo |
| Unity Behavior Tree | FSM actual en `GroundedEnemy`; destino H1/H2: LimboAI BT + HSM con blackboard |
| Unity Input System | `project.godot` input map |
| URP Shader Graph | Materiales/Shader Godot H3 |

## Verificacion

```powershell
$GODOT="C:/Users/Tutupa/Downloads/Godot_v4.7-stable_win64.exe"
& $GODOT --headless --path . --import
& $GODOT --headless --path . --quit-after 2
& $GODOT --headless --path . res://world/smoke_test.tscn --quit-after 2
```

## Relacionado

- [[Metodologia V2]]
- [[Integraciones]]
- [[Matriz Vault Unity Godot]]
- [[Combate]]
