# Egoist v2 — Godot 4.7

Port de Egoist (Unity → Godot 4.7, Jolt Physics, Forward Plus). **GDScript tipado estático** únicamente.
El diseño vive en la bóveda de Obsidian (`../../Boveda`) — misma fuente de verdad de siempre. Las reglas de skills del CLAUDE.md raíz (`/ponytail`, etc.) siguen aplicando.

**Metodología obligatoria**: antes de crear, modificar o borrar un sistema, seguir el flujo de [`METODOLOGIA.md`](METODOLOGIA.md) (incluye qué skill invocar: `/godot-gdscript-patterns` para diseñar, `/godot-best-practices` para escribir, `/godot-ui` para `ui/`).

## Reglas duras (lecciones de la v1)

1. **Git desde el commit 0.** Commit al cerrar cada feature que funcione; nunca más 2 semanas al aire.
2. **Todo valor tuneable vive en un Resource `.tres` en `data/`** — nunca hardcodeado ni solo en la escena. (En v1 un refactor reseteó los valores tuneados a mano.) *Excepción acordada:* el tuning de enemigos (`EnemyBase`, `MeleeAttack`, `RangedAttack`, `Perception`, `GroundLocomotion`) vive en `@export` por escena hasta que exista el segundo tipo de enemigo; ahí se extrae un `EnemyTuning` en `data/`.
3. **Claude edita las escenas `.tscn` como texto.** Tutupa juega, tunea `.tres` y decide diseño. Nada de "yo armo la escena, dime qué hago".
4. **Verificar headless antes de entregar** (ver abajo). Nunca declarar "listo" sin correr esto.
5. **Composición Godot-nativa**: `Health`/`WorldMembership`/etc. son nodos hijos; hitbox/hurtbox son `Area3D` + grupo `"hurtbox"`; comunicación por **señales**, nunca polling. Los contratos C# de v1 (`IHittable`/`ILaunchable`/`IParryable`) desaparecen: `has_method()` y grupos.
6. **HUD desde cero** (el de v1 era descartable).
7. **IA: FSM simple primero.** LimboAI solo si la FSM se queda corta (el BT de v1 era prototipo).

## Estructura (feature-based: escena + script juntos)

```
autoload/   WorldManager · GameManager · ComboTracker (singletons)
core/       World (enums) · WorldMembership · WorldSwitchTrigger
combat/     Health · Hurtbox · Hitbox · InputBuffer · weapons/ (WeaponBase, sword/)
data/       Resources de tuning (.gd de Resource + instancias .tres)
player/     Player (glue) + módulos: Locomotion · Dash · Launcher · Swing · Meter · LockOn
enemies/    EnemyBase · GroundedEnemy (glue) · Perception · GroundLocomotion · attacks/ · ai/
ui/         HUD (solo escucha señales)
visual/     CameraRig · WorldVisual · LandingIndicator
world/      Escenas: test_scene, bloques de traversal, pickups
assets/     Modelos, animaciones, texturas (binarios → LFS)
```

## Mapa Unity v1 → Godot v2

| Unity v1 | Godot v2 |
|---|---|
| `WorldManager.cs` singleton lazy | autoload `WorldManager` |
| eventos C# | señales |
| `CharacterController` + `PlayerMotor` | `CharacterBody3D` (velocity + `move_and_slide()`) — el motor ya viene |
| `IHittable` + `GetComponentInParent` | `Hurtbox` (Area3D) + grupo |
| `ILaunchable`/`IParryable` | `has_method("launch")` / `has_method("try_parry")` |
| bloques `[Serializable]` + `Init(...)` | nodos hijos |
| `ScriptableObject` (deuda nunca pagada) | Resource `.tres` en `data/` desde el día 0 |
| `TestSceneBuilder.cs` (hack de editor) | Claude escribe `world/test_scene.tscn` directo |
| Unity Behavior BT | FSM (enum + match) → LimboAI si hace falta |
| Input System asset | `[input]` en `project.godot` (move_up/down/left/right, jump, dodge, attack_x, attack_y) |
| Mixamo retarget Humanoid | mismo FBX/GLB, retarget con BoneMap en el importador |

## Verificación (obligatoria antes de entregar)

```bash
GODOT="C:/Users/Tutupa/Downloads/Godot_v4.7-stable_win64.exe"
"$GODOT" --headless --path . --import        # importa assets y construye cache de clases
"$GODOT" --headless --path . --quit-after 2  # arranca autoloads y sale; stderr debe estar limpio
```

Para correr una escena concreta: `"$GODOT" --path . res://world/test_scene.tscn`
