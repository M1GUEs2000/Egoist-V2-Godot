---
title: Auditoria Boveda vs Codigo 2026-07-09
tags:
  - egoist
  - auditoria
  - meta
status: resolved
---

# Auditoria Boveda vs Codigo (2026-07-09)

Revision cruzada entre la boveda de Obsidian y el codigo real del repo Godot, hecha por
dos agentes en paralelo: **fox** (Claude) cubrio Traversal/Combate/Armas + codigo
relacionado (`world/blocks`, `combat/weapons`, movimiento del player); **boar** (GPT-5.5)
cubrio Enemigos/IA/Areas/Tareas + codigo relacionado (`enemies/`, `ai/`, `core/world.gd`,
`test_scene`).

Estado del repo al momento de la auditoria: `git pull` aplicado, merge resuelto en
`world/test_scene.tscn` a favor de origin (traversal_block reemplazo prefabs viejos),
working tree limpio, 2 commits locales sin pushear.

**Regla del arreglo (2026-07-09): la boveda se corrige para reflejar el codigo real. No se
toco codigo ni escenas `.tscn` — el codigo manda, la boveda es la que estaba desactualizada
en todos los hallazgos reales.**

## Hallazgos de fox (Traversal / Combate / Armas)

### RESUELTO — `Lock On.md` desactualizado: dice stub, el sistema ya esta implementado

`obsidian/Gameplay/Combate/Lock On.md` (`system_status: E0`) decia: *"`player/lock_on.gd`
existe como stub"* y listaba como pendiente H1 "Adquirir target por direccion", "Reticle
sobre cabeza", "Exponer target visible solo con armas afuera", "Integrar snap en
`PlayerLocomotion`".

En realidad `player/lock_on.gd` tiene las 4 cosas implementadas: adquisicion de target
por direccion cuantizada a 16 direcciones (`_find_best_target`/`_quantize`), reticle
posicionado sobre el AABB combinado de las mallas del target (`_reticle_position`),
visibilidad condicionada a armas afuera (`has_visible_target`/`_is_weapons_out`), e
integracion con `PlayerLocomotion.tick` (`lock_on.set_aim_direction(camera_dir)`). Ademas
tiene cobertura en `world/smoke_test.gd` (adquiere el enemigo mas cercano en rango/angulo,
ignora el lejano). `METODOLOGIA.md`, `Deuda Tecnica.md` y `Matriz Vault Unity Godot.md`
tambien lo listaban como **E0 / stub**, repitiendo la desactualizacion en 3 lugares mas.

Nota: `player_swing.gd` (Cadenas), que SI esta correctamente documentado como stub real
de una linea, esta bien — no confundir los dos casos.

**Arreglado:** `Lock On.md` promovido a `system_status: E2`, `METODOLOGIA.md`,
`Deuda Tecnica.md` y `Matriz Vault Unity Godot.md` actualizados a la vez. Se aprovecho la
misma pasada para corregir `Landing Indicator` (mismo patron: la nota propia ya decia E2
correctamente, pero `Deuda Tecnica.md`, `METODOLOGIA.md` y `Matriz Vault Unity Godot.md`
seguian listandolo como E0/stub).

### RESUELTO — `WorldSwitchTrigger` parece codigo huerfano no usado en ninguna escena

`core/world_switch_trigger.gd` define `WorldSwitchTrigger` (modulo componible ON_HIT /
ON_DEATH) y esta documentado como parte activa del sistema en `World Switch.md`,
`Traversal.md`, `Enemigos.md`, `Estados de Combate Enemigo.md`, `Afiliacion de Mundo.md`,
`Matriz Vault Unity Godot.md` y `METODOLOGIA.md`. Sin embargo, no aparece instanciado en
ningun `.tscn` del repo (`player.tscn`, `test_scene.tscn`, `grounded_enemy.tscn`, etc.) —
la unica referencia funcional es en `world/smoke_test.gd`, que lo instancia a mano por
codigo dentro de un test.

El sistema real de world switch en `test_scene.tscn` usa `TraversalBlock.enable_world_switch`
(ver `traversal_block.gd`), que implementa la misma logica (`WorldManager.switch_world()`
en `_on_hit`) de forma inline, sin depender de `WorldSwitchTrigger`.

**Arreglado:** `World Switch.md` aclara ahora que `WorldSwitchTrigger` no se usa en ninguna
escena hoy (solo en el smoke test), que `TraversalBlock` implementa su propia logica
inline, y que el caso ON_DEATH sigue planeado pero sin instancia real. No se elimino
codigo — Tutupa no confirmo que sea descartable, y el modulo sigue siendo la pieza
planeada para ON_DEATH en enemigos.

### BAJA — `mace.tscn`: nombre de nodo raiz "Maso" en vez de "Mazo"

El nodo instanciado en `player.tscn` se llama `Maso` (linea 109: `[node name="Maso"
parent="." instance=ExtResource("15_mace_scene")]`), y el nodo raiz interno de
`mace.tscn` tambien es `Maso` (linea 31). El arma se llama "Mazo" en toda la boveda
(`Mazo.md`, `Armas.md`) y en el `class_name Mace`. No rompe nada (es solo un nombre de
nodo en el arbol de escena, `weapon_label()` usa `weapon.name.capitalize()` asi que el
label en UI seria literalmente "Maso"), pero es inconsistente con el nombre del arma en
toda la documentacion y probablemente un typo de tipeo rapido ("Maso" en vez de "Mazo").

**Sin resolver — es codigo, no boveda:** requiere editar `mace.tscn` y `player.tscn`
(renombrar nodo), fuera del alcance de esta pasada de "boveda debe reflejar el codigo".
Queda como pendiente cosmetico si se retoca esa escena.

### Confirmado como correcto (no son incongruencias)

- **Armor/`armor_hits_to_break`**: el flujo esta completo y consistente entre
  `enemy_base.gd` y `Stun.md`/`Armored Enemy.md`. `_damage_armor()` incrementa
  `_armor_hits_taken` (llamado desde `take_hit_from_enemy` y `on_hurtbox_hit`), y se
  resetea en `apply_armor()`/`set_armored()`/al romperse. No hay incongruencia real, solo
  la investigacion inicial no habia rastreado el incremento hasta el final.
- **`Mazo.md`**: coincide con el codigo actual — `_begin_ground_step` sin llamadas
  duplicadas, `_hold_x` cancela rutinas, `mace.gd` extiende `WeaponBase` directamente (no
  `Sword`), `ChargedDashHitbox` efectivamente no existe en `mace.tscn` (0 matches),
  coherente con la nota "ya no tiene ChargedDashHitbox (huerfano)".

  Ojo: esto contradice a `actualizador-boveda.md` (documento de trabajo, no la boveda
  final), que describe una version vieja donde `Mace` heredaba de `Sword` y mantenia
  `ChargedDashHitbox` como hitbox esperado. `actualizador-boveda.md` es explicitamente un
  changelog de traspaso ("cambios pendientes de commit al actualizar este documento"), asi
  que quedar desactualizado respecto al estado final es esperable — no es una
  incongruencia de la boveda real, pero vale la pena limpiarlo o archivarlo si ya se
  volco todo su contenido a las notas correspondientes.
- **Dagas/Punos**: correctamente marcados `status: planned` / `Estado Godot: No
  implementado` — no hay codigo para ninguna de las dos armas en `combat/weapons/`.
- **Meter, Stun universal, Momentum y Bump, Launcher y Aire, Wall Slide/Wall Jump,
  Dash y Airdash, Landing Indicator, Bloques (TraversalBlock/SpikeWall/BreakableWall),
  trampa de migracion Godot 4.7 (`node_paths`)**: todos verificados linea por linea
  contra el codigo, sin incongruencias.

## Hallazgos de boar (Enemigos / IA / Areas / Tareas)

### RESUELTO — `enemies/ai/README.md` obsoleto, contradice la decision de adoptar LimboAI

Contradecia la decision tomada el 2026-07-08 de adoptar LimboAI desde el inicio,
documentada en `obsidian/Gameplay/IA/IA.md` e `Integraciones.md`, y contradecia los YAML
de spec de IA actuales.

**Arreglado:** `enemies/ai/README.md` reescrito para reflejar la decision de LimboAI, que
el addon ya esta instalado en `addons/limboai/`, y que el plano vive en
`enemies/ai_spec/*.yaml`.

### RESUELTO — Todos los enemigos de `test_scene` heredan afiliacion Dead por defecto

`test_scene`/docs decian que solo el enemigo ultra-agresivo esta en mundo Dead, pero
`grounded_enemy.tscn` (la escena base reutilizada por todos) tiene
`WorldMembership.affiliation = DEAD` por defecto, y ninguna instancia en `test_scene` lo
overridea — todos los enemigos heredan Dead.

**Arreglado (en boveda):** `IA.md` corrige la descripcion de `test_scene` (todos, incluido
el ultra agresivo, son Dead por el default). `Roster Enemigos.md` y `Melee Living.md`
aclaran que hoy ningun enemigo esta seteado a Living y que eso requiere un prefab propio
(pendiente de codigo, no de boveda — no se cambio el default de `grounded_enemy.tscn` ni
se overrideo ninguna instancia porque no hay confirmacion de que ese sea el comportamiento
deseado para cada enemigo del roster).

### RESUELTO — Roster dice "Melee Living" pero no existe prefab separado

Roster H1 dice "Melee Living" deberia ser Living, pero la unica escena reutilizable
(`grounded_enemy.tscn`) esta afiliada a Dead; no hay prefab separado aun.

**Arreglado:** ver arriba (mismo fix que el hallazgo anterior, `Roster Enemigos.md` y
`Melee Living.md`).

### RESUELTO — `Pasivo.md` atribuye un metodo a la clase equivocada

El doc de Pasivo.md atribuye `_on_passive_attacked` a `EnemyBase` cuando en realidad vive
en `GroundedEnemy`.

**Arreglado:** `Pasivo.md` corregido a `GroundedEnemy._on_passive_attacked`.

### Confirmado como correcto (no son incongruencias)

- Estados `ATTACK_GROUP`/`EVADE`/`DEFEND`/`CALL_HELP` sin logica: ya documentados como
  pendientes.
- Falta prefab Ranged: ya documentado como pendiente.
- Reactivo sin zona propia: ya documentado como pendiente.

## Resumen priorizado

| Prioridad | Hallazgo | Autor | Tipo | Estado |
|---|---|---|---|---|
| ALTA | `enemies/ai/README.md` contradice la decision de usar LimboAI | boar | Doc obsoleta | Resuelto |
| ALTA | `Lock On.md` dice stub (E0), el sistema ya esta implementado (E2+) | fox | Doc desactualizada | Resuelto |
| MEDIA/ALTA | Todos los enemigos de `test_scene` heredan Dead por el default de `grounded_enemy.tscn` | boar | Doc vs escena | Resuelto en boveda; codigo/prefab Living sigue pendiente |
| MEDIA | Roster dice "Melee Living" pero no hay prefab Living separado | boar | Doc vs escena | Resuelto en boveda; prefab sigue pendiente |
| MEDIA | `WorldSwitchTrigger` parece codigo huerfano, sin uso en ninguna escena | fox | Codigo huerfano / doc desalineada | Resuelto en boveda; codigo no tocado |
| MENOR | `Pasivo.md` atribuye `_on_passive_attacked` a la clase equivocada | boar | Error de doc puntual | Resuelto |
| BAJA | Nodo `Maso` en vez de `Mazo` en `mace.tscn`/`player.tscn` | fox | Typo cosmetico | Sin resolver (es codigo, no boveda) |
| — | `Landing Indicator` listado como E0/stub en `Deuda Tecnica.md`, `METODOLOGIA.md`, `Matriz Vault Unity Godot.md` pese a estar implementado (E2) | fox | Doc desactualizada | Resuelto (encontrado durante el arreglo de Lock On) |

## Relacionado

- [[Enemigos]]
- [[Combate]]
- [[Traversal]]
- [[Armas]]
- [[IA]]
