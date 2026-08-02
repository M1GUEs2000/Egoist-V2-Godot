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
| Movimiento dirigido | [[Mover y Floater]] (`MoverSettings` y `FloaterSettings`) |
| Gestos y carga | [[Taps Direccionales]], [[Sweet Spots]], `InputBuffer` |
| Meter | `PlayerMeter` |
| Loadout | `ActionLoadoutMenu` (overlay en HUD) |
| Stun del player | `PlayerStun` (nodo hijo `Stun`) |

## Reglas actuales

- El meter que se GANA lo decide la fuente (cada arma trae su `WeaponTuning.meter_gain_on_hit` /
  `meter_gain_on_kill`); el que se GASTA vive en `PlayerTuning`. `PlayerMeter` no lee ganancias: las
  recibe. Detalle en [[Meter]]. *(2026-07-28, reemplaza la ganancia global unica para todas las armas)*
- **Ningun cargado es gratis**: el Y cargado terrestre (launcher) de Espada y Mazo pasa a costar 1
  barra, y sin barra cae al tap normal. El gesto `tap atras + Y` del lock-on sigue gratis porque es
  un tap, no un cargado. *(2026-07-28, pendiente de tunear jugando)*
- Mientras un ataque esta cargado, el HUD **late** sobre el tramo de meter que va a consumir,
  descontado desde el tope hacia abajo. El monto lo calcula el arma
  (`WeaponBase.charged_meter_cost`), no el HUD. Ver [[Meter]] > Preview de gasto. *(2026-07-28)*
- Slot X es ataque ligero; slot Y es ataque pesado.
- La misma arma cambia comportamiento segun slot.
- Las armas son procedurales hasta H3: no dependen de animaciones de combate.
- El arma del jugador la mueve la animacion: el hitbox cuelga del hueso de la mano (ver seccion De donde sale el arco de un golpe).
- El stun es universal: la fuente define potencia/duracion/tipo (`StunSettings`), pero el receptor decide si entra con su threshold (ver seccion Stun universal). *(2026-07-07)*
- El **parry hace daño de poise, no de HP**: contragolpear a un enemigo en su ventana mete poise (monto por arma y por tipo de ataque, `WeaponTuning.parry_poise_normal/_charged_x/_charged_y`). Si quiebra la reserva → estado **vulnerable cian** + stun 1.5s + daño multiplicado (`ParryTuning`, `data/parry_tuning.tres`); si no, fogonazo blanco. El X cargado (dash) y el Y cargado terrestre (launcher) ahora también parrian. Detalle en [[Stun]] > Parry. *(2026-07-14, reemplaza el parry de stun plano; pendiente de tunear jugando)*
- Los **proyectiles enemigos son parryables**, pero su parry es un **deflect**, no el cian: el arma da vuelta el proyectil y lo manda homing contra quien lo tiró, que se auto-staggerea comiendo el daño y el stun de su propio tiro. No abre el estado vulnerable ni usa `current_parry_poise` (`Projectile.try_parry`; knobs en `DeflectTuning`, `data/deflect_tuning.tres`). Detalle en [[Stun]] > Parry de proyectil. *(2026-07-14, pendiente de tunear jugando)*
- El dodge tiene i-frames: mientras dura la ventana (`PlayerTuning.dodge_iframe_duration`) el player no puede ser stuneado (gate en `Player.try_apply_stun`, ver [[Stun]] > I-frames del dodge). No aplica al `force_dash` ofensivo. El esquive enemigo (`EVADE`) todavia no existe (planeado H2). *(2026-07-13, pendiente de tunear jugando)*
- Cada golpe de un combo, en tierra o en aire, avanza al jugador hacia el enemigo lockeado (o hacia su frente) con `Player.attack_step`. Distancia en `PlayerTuning.attack_step_distance`. *(2026-07-09)*
- El golpe aereo flota solo si conecta; si falla, cae mas fuerte. Un golpe aereo normal conectado tambien suspende al enemigo golpeado con un Floater propio, simetrico al hang del jugador (ver [[Espada]] `air_hit_enemy_floater`).
- Un move puede pedir un **hang propio** con `Player.request_float(duration, fall_scale)` (componente Floater, ver [[Plan Autoridad Vertical]]): frena la caida en seco (o la escala) y sostiene al jugador un tiempo exacto, sin gastarle el doble salto. **Salto y Floater se cancelan mutuamente** (gana el ultimo pedido): saltar —piso, doble salto, wall jump o rebote en enemigo— corta cualquier hang activo, y a la inversa un golpe que pide Floater cancela el salto en curso, suba o caiga, y toma la vertical. `request_float` no actua en piso ni mientras el dash es dueño de la vertical (el dash cargado la conserva hasta terminar).
- El finisher aereo usa los verbos `slam`, `push` y `slam_bounce` de `EnemyBase`. `push` es una mecanica aislada con solver propio (no depende de Mover/Floater). `slam`/`slam_bounce` (y `slam_arc` del Mazo) describen arcos balisticos que el Mover lineal todavia no cubre: esperan el "bouncer" (Mover en modo balistico) planeado en [[Plan Autoridad Vertical]] F5, sin fecha.
- El combo aereo `X espera X X`: la primera vuelta eleva un poco al jugador (hop, `air_wait_spin_hop`). *(2026-07-06)*
- El push es un verbo generico que cualquier ataque puede armar con `WeaponBase.arm_push`: a `push_at` del swing empuja lo ya golpeado, y lo que conecte despues se empuja al instante. Usa `WeaponTuning.push` y sirve en tierra o aire. *(2026-07-09)*
- Un enemigo empujado (`push`) o stuneado en el aire cae **acostado** y, al tocar el piso, pasa a un ragdoll fisico (RigidBody capsula) que rueda y se para en ~0.5s. Solo cambia la pose y la reaccion de aterrizaje; el hang del stun y el arco del push no se tocan (ver [[Stun]]). *(2026-07-10)*
- Los enemigos tambien son superficies de traversal: el player puede rebotar desde su colision con `PlayerEnemyBounce`; si `enemy_bounce_push` existe, el enemigo recibe `push()` como reaccion opcional.
- El hang del jugador al conectar un golpe aereo normal es un `FloaterSettings` por arma (`WeaponTuning.air_hit_player_floater`): duracion y `fall_scale` fijos, renovados por golpe (el Floater usa `max()`), sin escalado por combo. *(2026-07-21)*
- La hoja brilla al cargar un ataque (glow ambar proporcional a `InputBuffer.charge_progress`, tuneable con `charge_glow_color` / `charge_glow_max_energy`). El halo ya existe: `test_scene` tiene un `WorldEnvironment` con glow (HDR threshold 1.0, tonemap Filmic); falta tunear el bloom jugando. *(2026-07-10)*
- Al empezar una carga en aire, `Player.apply_air_charge_float()` cuelga al jugador con un Floater (`PlayerTuning.air_charge_floater`, un `FloaterSettings`), sin escalado ni anti-spam; no toca momentum horizontal. `PlayerAirKillReset` solo devuelve doble salto y airdash al matar en aire. *(2026-07-21)*

## Autoridad vertical

La referencia de implementacion, perfiles, modos TOTAL/PARTIAL y reglas de cancelacion vive en
[[Mover y Floater]].

Los ataques deciden los perfiles `MoverSettings` y los datos de `Floater`; Player y EnemyBase solo
los ejecutan. Un Mover TOTAL toma el cuerpo completo y uno PARTIAL controla solo Y, conservando los
contactos y la locomocion del Player. Todo golpe nuevo que afecte a un enemigo cancela su
Mover/Floater anterior, salvo el perfil preparado por ese mismo golpe antes del dano.

Espada usa Mover/Floater para sus rutas verticales, incluido hop, finisher y plunge. Todos los floats
verticales del jugador (impacto aereo, sweet spot, dash, carga aerea, Brazo) son `FloaterSettings` por
ataque, igual que los Movers; el whiff conserva gravedad normal y el rebote del Y aereo esta
desactivado. Mazo se reconstruyo sobre el mismo contrato (2026-07-21): su launcher terrestre pide un
`MoverSettings` propio para el enemigo (antes lo tenia cableado en null y no elevaba a nadie); su Y
cargado aereo se borro por completo en vez de migrarlo, porque dependia de un rebote balistico que
necesita el "bouncer" todavia sin diseñar (ver [[Plan Autoridad Vertical]] F5). El ground pound de su
X cargado aereo sigue escribiendo `vertical_velocity` directo a proposito: es una caida recta, no un
arco balistico.

## De donde sale el arco de un golpe

**El arma del jugador la mueve la animacion**, no un tween. El `BladeHitbox` y los meshes de la hoja cuelgan del `BoneAttachment3D` del hueso de la mano (marcados con el grupo `hand_attachment_payload` en la escena del arma), asi que el arma golpea exactamente donde el clip la pone. Que tramo de clip dibuja cada golpe y en que fraccion de ese tramo el hitbox esta abierto lo declara su `AttackClip`. Ver [[Contrato AttackClip]].

```text
Arma (WeaponBase)
├── Hand/Pivot (Node3D)      <- percha vacia tras el reparent: sostiene lo que se crea en runtime
│   ├── BladeMesh            <- grupo hand_attachment_payload -> al hueso
│   └── BladeHitbox          <- grupo hand_attachment_payload -> al hueso
└── AirDiscHitbox            <- NO va al hueso: disco alrededor del player en golpes aereos
```

> [!warning] Contrato de escena
> Un arma sin `Hand/Pivot` no carga: `WeaponBase` resuelve esas rutas con `@onready`. Y el hitbox de la hoja tiene que llevar el grupo del payload — si se lo olvida, vuelve el problema de las dos espadas: una que se ve y otra que golpea.

La **mano orbital** (un nodo `Hand` que rota alrededor del cuerpo llevando una hoja rigida, con angulos como `combo_swing_angle` y `hand_radius`) sigue viva pero solo en los **enemigos**, en `enemies/attacks/melee_attack.gd`. Sus armas todavia no se dibujan con clips.

## Loadout X/Y

Overlay para asignar armas a los slots X/Y sin pausar el juego (`ui/action_loadout_menu.tscn` + `.gd`, instanciado dentro del HUD). *(2026-07-07, pendiente de probar)*

- Se abre/cierra con `Tab` (input action `open_loadout_menu`); el juego sigue corriendo, no se toca `get_tree().paused`.
- Al presionar `Slot X` o `Slot Y` se listan las armas disponibles: `PlayerCombat.available_weapons`, que hoy son los nodos hijos del `Player` que hereden de `WeaponBase`.
- Equipar llama `PlayerCombat.set_slot_weapon` (emite `slots_changed`); la misma arma puede ir en ambos slots, y solo se ve en el player lo asignado a slots.
- Un slot sin arma no hace nada al presionarlo: no ataca, no dispara `fire_action_world_switch`, no actualiza `_last_attack_time` ni cuenta como arma afuera.
- No hay persistencia/save de loadout todavia.

## Stun universal

El stun se gana por **poise** (stagger acumulado), no golpe a golpe. La fuente define cuanto poise come y cuanto dura; el receptor se quiebra cuando el acumulado alcanza su reserva. Player y enemigos comparten el mismo medidor (`combat/poise.gd`). El detalle completo — ciclo, degradacion, armadura y tuning — vive en [[Stun]]. *(2026-07-13, reemplaza el umbral instantaneo; pendiente de tunear jugando)*

- `StunSettings` lleva `poise_damage` (cuanto poise come) + `grounded` / `airborne` (cuanto dura si quiebra).
- Entrada normal: `receive_stun` / `try_apply_stun` (comen poise y stunean solo si quiebran). `apply_stun` queda como aplicacion directa, ignorando el poise (ej. parry).
- La armadura no da inmunidad: **suma reserva** (`armor_poise_bonus`), y la pierde al romperse.
- Cada quiebre degrada la reserva del enemigo un escalon (`poise_break_levels`); el player **no degrada**. Sin golpes por 20 s, la reserva vuelve al 100%.
- Cuatro colores de impacto: **rojo** = golpe conectado (fogonazo breve), **blanco** = poise absorbido (no quebro), **amarillo** = stuneado y **celeste** = vulnerable por parry.
- El player puede ser stunned: `PlayerStun` mantiene duracion/modo y emite `stunned_started` / `stunned_ended`. Durante el stun se bloquea input y se cancelan locomotion, wall slide, launcher, dash y el buffer de combate (`PlayerCombat.cancel_input`). Mientras dura, su mesh emite amarillo (`stun_color` / `stun_emission_energy` en `PlayerTuning`).
- Modos del player (`PlayerStun.Mode`): `STILL` (quieto, sin input) y `PUSH` (sin input + empuje horizontal + velocidad vertical; para pinchos, rebotes y golpes que desplazan).
- Tuning en `PlayerTuning` grupo Stun: `default_stun_duration`, `stun_gravity_scale`, `stun_bump_decay`, mas el subgrupo Poise (`poise_max`, `armor_poise_bonus`, `poise_decay_per_second`, `poise_break_levels`, `poise_recovery_time`) y el fogonazo blanco (`poise_chip_color` / `poise_chip_emission_energy` / `poise_chip_time`).

## Momentos de gravedad (regla de correlacion)

Todos los momentos de gravedad del player (launcher float/fall, air stall, whiff, stun, wall slide) son **escalas multiplicativas** de `PlayerTuning.gravity`; las **velocidades verticales** usan su knob propio. Salto y doble salto calculan su propia parabola desde `jump_min_apex_height` / `jump_max_apex_height`, `jump_duration` y un impulso horizontal derivado; hops, rebotes y wall jump conservan sus knobs especificos. *(2026-07-21)*

- Al retunear la gravedad base, conservar el feel de un momento exige re-derivar su escala: `escala_nueva = escala_vieja x (g_vieja / g_nueva)`.
- Al retunear velocidades verticales, la convencion es conservar el tiempo de subida y escalar la altura (si la gravedad se duplica, la velocidad se duplica).
- Alturas/tiempos posicionales (launcher `height`/`hang_time`, `meet_height`) son independientes de la gravedad: no se convierten.
- El arco del push de cada arma lleva su propio impulso (`PushSettings.initial_speed`) y aceleracion vertical (`PushSettings.acceleration`). El angulo admite valores negativos para empujar hacia abajo. `stop_on` usa los mismos flags de Mover (Distance, Floor, Wall, Hit); por defecto Wall esta desmarcado para permitir el rebote configurado.
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
- Probar reset aereo por kill y reduccion de caida al cargar en aire.
- Decidir knockback de golpes normales.
- Rehacer HUD de combate para armas, meter, combo y cooldowns.

## Go/no-go

> [!danger]
> La pregunta de H1 sigue siendo: "Pelear con Espada cambiando de mundo se siente bien?" Si no, se redisenia antes de H2.

## Relacionado

- [[Armas]]
- [[Traversal]]
- [[Enemigos]]
- [[hitos]]
