---
title: Combate
tags:
  - egoist
  - gameplay
  - sistema
  - combate
status: active
system_status: E2
hito: H1
---

# Combate

Combate del jugador: slots X/Y, espada, hitboxes, parry, meter, combo aereo e input feel.

## Implementado en Godot

| Pieza | Modulos |
|---|---|
| Golpeables | `Health`, `Hurtbox`, `Hitbox` |
| Input | `InputBuffer` |
| Combo global | `ComboTracker` |
| Armas | `WeaponBase`, `Sword`, `Mace` (combos alineados con Espada, E2 pend. playtest, ver [[Mazo]]) |
| Tuning | `WeaponTuning`, `SwordTuning`, `StunSettings`, `PushSettings`, `PlayerTuning` |
| Meter | `PlayerMeter` |
| Loadout | `ActionLoadoutMenu` (overlay en HUD) |
| Stun del player | `PlayerStun` (nodo hijo `Stun`) |

## Reglas actuales

- Slot X es ataque ligero; slot Y es ataque pesado.
- La misma arma cambia comportamiento segun slot.
- La espada es procedural hasta H3: no depende de animaciones de combate.
- El stun es universal: la fuente define potencia/duracion/tipo (`StunSettings`), pero el receptor decide si entra con su threshold (ver seccion Stun universal). *(2026-07-07)*
- El golpe aereo flota solo si conecta; si falla, cae mas fuerte.
- El finisher aereo usa verbos opcionales `slam`, `push` y `slam_bounce`.
- El combo aereo `X espera X X`: la primera vuelta eleva un poco al jugador (`Player.air_hop`, tuneable con `air_wait_spin_hop`). El air-hit-stall preserva subidas (no corta velocidad vertical positiva), asi el hop sobrevive al stall. *(2026-07-06)*
- El push es un verbo generico que cualquier ataque puede armar con `WeaponBase.arm_push`: a `push_at` del swing empuja lo ya golpeado, y lo que conecte despues se empuja al instante. Usa `WeaponTuning.push` y sirve en tierra o aire. *(2026-07-09)*
- Cada arma escala cuanto sostiene en el aire un golpe conectado con `air_stall_scale`; el Player calcula el stall base y el arma multiplica el resultado. *(2026-07-09)*
- La hoja brilla al cargar un ataque (glow ambar proporcional a `InputBuffer.charge_progress`, tuneable con `charge_glow_color` / `charge_glow_max_energy`). Sin bloom aun: falta un `WorldEnvironment` con glow para el halo. *(2026-07-06)*

## Loadout X/Y

Overlay para asignar armas a los slots X/Y sin pausar el juego (`ui/action_loadout_menu.tscn` + `.gd`, instanciado dentro del HUD). *(2026-07-07, pendiente de probar)*

- Se abre/cierra con `Tab` (input action `open_loadout_menu`); el juego sigue corriendo, no se toca `get_tree().paused`.
- Al presionar `Slot X` o `Slot Y` se listan las armas disponibles: `PlayerCombat.available_weapons`, que hoy son los nodos hijos del `Player` que hereden de `WeaponBase`.
- Equipar llama `PlayerCombat.set_slot_weapon` (emite `slots_changed`); la misma arma puede ir en ambos slots, y solo se ve en el player lo asignado a slots.
- Un slot sin arma no hace nada al presionarlo: no ataca, no dispara `fire_action_world_switch`, no actualiza `_last_attack_time` ni cuenta como arma afuera.
- No hay persistencia/save de loadout todavia.

## Stun universal

La fuente del stun define potencia, duracion y tipo; el receptor decide si entra segun su threshold: `stun_power >= threshold efectivo`. Player y enemigos comparten el mismo criterio. *(2026-07-07, pendiente de probar; valores de primer pase)*

- `StunSettings` lleva `power` (y `beats_threshold`).
- Entrada normal: `receive_stun` / `try_apply_stun` (respetan resistencia). `apply_stun` queda como aplicacion directa.
- La armadura no da inmunidad al stun: sube el threshold requerido (`armor_stun_threshold`).
- El player puede ser stunned: `PlayerStun` mantiene duracion/modo y emite `stunned_started` / `stunned_ended`. Durante el stun se bloquea input y se cancelan locomotion, wall slide, launcher, dash y el buffer de combate (`PlayerCombat.cancel_input`).
- Modos del player (`PlayerStun.Mode`): `STILL` (quieto, sin input) y `PUSH` (sin input + empuje horizontal + velocidad vertical; para pinchos, rebotes y golpes que desplazan).
- Tuning en `PlayerTuning` grupo Stun: `default_stun_duration`, `stun_threshold`, `armor_stun_threshold`, `stun_gravity_scale`, `stun_bump_decay`.

## Momentos de gravedad (regla de correlacion)

Todos los momentos de gravedad del player (launcher float/fall, air stall, whiff, stun, wall slide) son **escalas multiplicativas** de `PlayerTuning.gravity`; las **velocidades verticales** (salto, hops, rebotes, wall jump) se anclan a `jump_force`. Anclas actuales en `player_tuning.tres`: `gravity = -40`, `jump_force = 17`. *(2026-07-07)*

- Al retunear la gravedad base, conservar el feel de un momento exige re-derivar su escala: `escala_nueva = escala_vieja x (g_vieja / g_nueva)`.
- Al retunear velocidades verticales, la convencion es conservar el tiempo de subida y escalar la altura (si la gravedad se duplica, la velocidad se duplica).
- Alturas/tiempos posicionales (launcher `height`/`hang_time`, `meet_height`) son independientes de la gravedad: no se convierten.
- El arco del push de cada arma lleva su propia gravedad (`PushSettings.gravity`); la de la espada esta alineada con la base (-40).
- `EnemyBase.airborne_gravity` (-20) es la gravedad propia de cada enemigo, independiente de la del player; si el mundo entero debe sentirse igual de pesado, se ajusta aparte en los prefabs.

## Trampa de migracion (Godot 4.7)

> [!bug] El ataque dejo de salir tras abrir el proyecto en Godot 4.7
> `PlayerCombat` expone `@export var slot_x/slot_y: WeaponBase` (referencia a nodo **tipada**). En `player.tscn` estaban asignadas como `slot_x = NodePath("../Sword")`, pero **sin** el header `node_paths=PackedStringArray("slot_x", "slot_y")` en el bloque del nodo `Combat`. El loader de 4.7 ya no resuelve un export de nodo tipado desde un `NodePath` plano: lo descarta y deja la propiedad en `null`. Con `slot_x`/`slot_y` en `null`, `PlayerCombat._on_press` cortaba en `if weapon == null: return` antes de tocar la espada (ni swing ni dano). Como la espada nunca recibia `setup()`, tampoco tenia `_player`.

**Fix:** agregar el header al nodo que tenga exports de nodo tipados:

```text
[node name="Combat" type="Node" parent="." node_paths=PackedStringArray("slot_x", "slot_y")]
```

**Regla general:** cualquier `@export var x: <TipoNodo>` asignado por `NodePath` en un `.tscn` viejo necesita ese header para resolver en 4.7. Si no aparece error visible es porque el modulo tiene fallback (ej. `CameraRig.target` cae a `get_first_node_in_group("player")`); el combate no lo tenia, por eso el `null` mataba el ataque en silencio. Al abrir escenas viejas en 4.7, revisar los exports de nodo tipados.

## Pendiente H1

- Probar y tunear espada X/Y en suelo y aire.
- Confirmar si hold debe cancelar tap; si si, usar modo de input de carga exclusiva.
- Completar reset aereo por kill.
- Decidir knockback de golpes normales.
- Rehacer HUD de combate para armas, meter, combo y cooldowns.
- Implementar lock-on como parte del feel de combate.

## Go/no-go

> [!danger]
> La pregunta de H1 sigue siendo: "Pelear con Espada cambiando de mundo se siente bien?" Si no, se redisenia antes de H2.

## Relacionado

- [[Armas]]
- [[Traversal]]
- [[Enemigos]]
- [[H1 - Vertical Slice]]
