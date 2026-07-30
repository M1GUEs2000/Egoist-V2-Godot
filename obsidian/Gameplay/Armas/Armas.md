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

Los ataques que ya migraron no llegan al ultimo nivel: en vez de campos por cuerpo llevan **un Resource por gesto** (`AttackMovementProfile`) o **por cadena** (`AttackSequence`), y los campos sueltos que quedan debajo son los que no son posicion. Ver las dos secciones de abajo.

Reglas:

- **Un campo por cuerpo que el golpe realmente mueve.** Un Mover o un Floater solo controla a su dueno (ver [[Mover y Floater]]), asi que mover a los dos son dos perfiles. Para campos SUELTOS del tuning sigue valiendo que no se crean vacios por simetria; dentro de un `AttackMovementProfile` la regla se invierte (ver mas abajo).
- **Un perfil por golpe.** Dos golpes que hoy se sienten igual llevan perfiles separados igual, para poder tunearlos aparte sin que uno arrastre al otro.
- **Nombre = gesto + tramo + cuerpo + primitiva**, en ese orden: `tap_back_y_air_enemy_mover`. El prefijo del grupo hace que el inspector muestre solo la cola.
- Lo que comparten varios golpes va a un grupo `Comun a varios golpes`, no se duplica.
- Todo `@export` de tuning lleva comentario `##` encima (que hace, unidades, efecto): es el tooltip del inspector.

### Un perfil por gesto, no un campo por primitiva

Cuando un golpe acumula muchas primitivas, sus campos sueltos dejan de caber: la variante aerea RT de `tap atras + X` llego a ser **cinco campos repartidos en tres subgrupos** mas los ids de rutina que el arma guardaba para reconectarlos al vuelo. A partir de ahi la agrupacion correcta es un `AttackMovementProfile` por **gesto** (gesto x tramo), con los knobs de coreografia e input debajo. *(2026-07-29)*

```
@export_group("Tap X atras", "tap_back_x_")
  tap_back_x_ground · tap_back_x_air
  @export_subgroup("Coreografia e input")
    tap_back_x_window · tap_back_x_air_spins · tap_back_x_meter_air_spins
```

El perfil responde una sola pregunta: **que le hace este golpe a la posicion de los cuerpos.** Ventanas, vueltas y coste de meter NO entran — si entra todo, el Resource deja de tener un tema y vuelve a ser una bolsa. Los slots y su semantica estan en [[Mover y Floater]] > Perfil de movimiento por ataque.

### Todos los especiales llevan perfil, aunque tengan slots vacios

Un `AttackMovementProfile` va en **todos** los ataques especiales del arma —taps direccionales y cargados— y no solo en los que hoy mueven a alguien. Un slot vacio adentro no es un olvido: es la forma de decir "este golpe no hace eso", y es lo que permite **agregar o sacar movimiento sin tocar codigo**. La rutina del golpe ya no pide Movers por su cuenta; `WeaponBase` los cobra desde el perfil en el momento que el perfil declare. *(2026-07-29)*

Esto invierte a proposito la regla de arriba para el caso de los perfiles. La regla original ("no se crean campos vacios por simetria") se escribio porque un campo vacio y un campo olvidado se ven igual en el inspector — el problema real que dejaron los cinco huecos de RT. Dentro de un perfil por gesto ese costo desaparece: el hueco tiene vecinos que le dan contexto y una semantica documentada. La regla sigue viva para los campos **sueltos** del tuning.

Una sola excepcion, porque ahi un slot mentiria: **X cargado**. No mueve al Player con un Mover sino con `force_dash`, que trae i-frames, hitbox propio y reposicionamiento al atravesar al objetivo. Cambiarlo a Mover no seria prender un slot, seria rediseñar el move y perder esas tres cosas.

### Los combos tambien son datos

Un `AttackSequence` por cadena, con un `AttackStep` por golpe. Cada paso trae su clip, su duracion, su `damage_scale`, y **su propio `AttackMovementProfile`** — asi que "el Mover sale en el tercer golpe" se declara en el inspector. Las ramas por espera son `AttackBranch`: despues del golpe N, tardar mas de `threshold` reemplaza toda la cola de la cadena. *(2026-07-30)*

Un combo puede tener **varias** ramas: el aereo de [[Espada]] ramifica tras el golpe 1 (vueltas) y tras el 2 (plunge). Solo entra una por corrida — metido en una rama, sus pasos mandan hasta el final.

> [!warning] Un paso = un golpe
> Cada `AttackStep` abre y cierra **su propia ventana de daño**. Antes una cadena de N golpes abria UNA ventana estirada sobre todos, asi que el enemigo cobraba una sola vez aunque vieras cuatro impactos — el tap adelante + X ya salia con dos vueltas y un golpe. Migrar multiplica el daño de toda cadena de mas de un paso; para eso esta `damage_scale` por paso, que es mas fino que bajar el daño base del arma (ese tambien afecta a los especiales).

Lo que un paso **no** dueña es el arco de la mano. Mientras el hitbox siga colgando del pivot orbital, `AttackStep.choreography` es un nombre que el arma traduce a su tween. Ese campo es transitorio: cuando el hitbox cuelgue del hueso, el arco ES la animacion y no hay nada que declarar.

### La variante RT es un porcentaje, no otro perfil

El primer intento fue un perfil por **variante** (gesto x tramo x RT), o sea el doble de perfiles. No funciono: obligaba a reescribir un recorrido entero para cambiar cuanto retrocede el RT, y los gestos que no usaban la variante dejaban slots vacios indistinguibles de un olvido —llegaron a ser cinco—. *(2026-07-29)*

La forma correcta es la que ya usa [[Sprint]] con sus canales: **el valor base vive una sola vez y RT entra como bono en % aplicado en el consumidor.** "Sin RT" pasa a ser multiplicar por `1.0` en vez de una rama con datos propios, y un hueco deja de existir porque `0%` es un valor legitimo.

Regla general para cualquier arma: **si la variante es "lo mismo pero mas", va porcentaje; si es otro golpe, va estructura.** Cuando una variante agrega algo que la base no tiene, se marca con un flag (`rt_only`, `rt_fires_projectile`) en vez de duplicar el perfil — un bool es mas barato que un Resource y no se puede desincronizar del base.

Lo que NO entra al modelo porcentual: valores clampeados donde un bono no tiene a donde ir (`fall_scale`), y los perfiles que no le pertenecen al dueno del ataque (el launcher del proyectil). Esos van a mano.

Y ojo con la otra mitad de la regla: **que RT sea un porcentaje no significa que todos los porcentajes de RT vivan en el perfil.** El bono de dano de RT es porcentual igual, pero el dano no es posicion, asi que vive en el tuning del arma junto a las vueltas —el otro knob de RT que tampoco es posicion—. La prueba es `tap adelante + X` en suelo: su perfil esta en `null` porque no mueve a nadie, y meterle el dano lo obligaria a existir solo para llevar un numero. El criterio sigue siendo el tema del Resource, no el tipo de dato. *(2026-07-29)*

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

