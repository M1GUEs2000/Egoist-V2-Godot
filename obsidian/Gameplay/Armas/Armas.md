---
title: Armas
tags:
  - egoist
  - gameplay
  - armas
  - combate
status: active
system_status: E2
hito: H1
---

# Armas

4 armas en total. Se equipan en slot X (ligero) o Y (pesado). El comportamiento cambia segun el slot. Los ataques cargados y el sweet spot son mecanicas transversales a todas las armas; ver [[Combate]].

> [!info] Scope
> Las 4 armas son el roster definitivo: [[Espada]], [[Mazo]], [[Dagas]] y [[Punos]]. H1 se concentra solo en Espada.

## Reglas base

- Dos slots: X/Y.
- Tap y hold.
- La personalidad depende del slot.
- Misma arma en ambos slots permitido; el loadout X/Y ya existe como overlay con `Tab` (ver [[Combate]]). *(2026-07-07)*
- Los cargados consumen meter.
- Sweet spot es una capa transversal de perfeccion/timing.

## Roster

| Arma | Rol | Hito |
|---|---|---|
| [[Espada]] | Base/equilibrada, mantiene flujo. | H1 |
| [[Mazo]] | Mas dano, control de masas, knockback. | H2 |
| [[Dagas]] | Movilidad, persecucion, teletransporte. | H2 |
| [[Punos]] | Agarre, mover enemigos o moverte tu, conecta con world switch. | H2 |

## Organizacion del tuning

Cada arma tiene su recurso propio (`SwordTuning`, `MaceTuning`) que extiende `WeaponTuning`, con la instancia editable en `data/`. Lo que es transversal al arma —swing time, push, parry, meter, sweet spot— vive en `WeaponTuning`; lo que es personalidad de un golpe vive en el recurso del arma.

El inspector se agrupa por **tipo de ataque, nunca por tipo de dato**. No existe un grupo "Movers" ni "Floaters": cada perfil vive junto al golpe que lo emite.

| Nivel | Que separa | Ejemplo |
|---|---|---|
| `@export_category` | Familia de ataque | Ataques normales (tap) · Cargados (hold) · Taps direccionales |
| `@export_group` | Golpe concreto, con prefijo de nombre para que el inspector lo recorte | `Tap Y atras`, prefijo `tap_back_y_` |
| `@export_subgroup` | Tramo y primitiva | `Suelo — Mover`, `Aire — Mover`, `Aire — Floater` |
| Campo | Cuerpo receptor | `tap_back_y_air_player_mover` / `tap_back_y_air_enemy_mover` |

Reglas:

- **Un campo por cuerpo que el golpe realmente mueve.** Un Mover o un Floater solo controla a su dueno (ver [[Mover y Floater]]), asi que mover a los dos son dos perfiles. Si el golpe toca a uno solo, hay un campo solo: no se crean campos vacios por simetria.
- **Un perfil por golpe.** Dos golpes que hoy se sienten igual llevan perfiles separados igual, para poder tunearlos aparte sin que uno arrastre al otro.
- **Nombre = gesto + tramo + cuerpo + primitiva**, en ese orden: `tap_back_y_air_enemy_mover`. El prefijo del grupo hace que el inspector muestre solo la cola.
- Lo que comparten varios golpes va a un grupo `Comun a varios golpes`, no se duplica.
- Todo `@export` de tuning lleva comentario `##` encima (que hace, unidades, efecto): es el tooltip del inspector.

### Un perfil por variante, no un campo por primitiva

Cuando un golpe acumula muchas primitivas, sus campos sueltos dejan de caber: la variante aerea RT de `tap atras + X` llego a ser **cinco campos repartidos en tres subgrupos** mas los ids de rutina que el arma guardaba para reconectarlos al vuelo. A partir de ahi la agrupacion correcta es un `AttackMovementProfile` por **variante** (gesto x tramo x RT), con los knobs de coreografia e input debajo. *(2026-07-29)*

```
@export_group("Tap X atras", "tap_back_x_")
  tap_back_x_ground · tap_back_x_ground_meter · tap_back_x_air · tap_back_x_air_meter
  @export_subgroup("Coreografia e input")
    tap_back_x_window · tap_back_x_air_spins · tap_back_x_meter_air_spins
```

El perfil responde una sola pregunta: **que le hace este golpe a la posicion de los cuerpos.** Ventanas, vueltas y coste de meter NO entran — si entra todo, el Resource deja de tener un tema y vuelve a ser una bolsa. Los slots y su semantica estan en [[Mover y Floater]] > Perfil de movimiento por ataque; [[Espada]] lo usa en sus taps de X.

[[Espada]] es la referencia implementada de esta organizacion.

## Notas

- El orden de desbloqueo por area vive en [[Areas]].
- La implementacion Godot cubre [[Espada]]; [[Mazo]] esta en desarrollo activo con combos propios sobre `WeaponBase` (E2), pendiente de playtest. *(2026-07-09)*
- No agregar armas nuevas al backlog activo sin moverlas primero a [[hitos]].

## Relacionado

- [[Combate]]
- [[Mover y Floater]]
- [[Areas]]
- [[README]]

