---
title: Meter
tags:
  - egoist
  - gameplay
  - sistema
  - combate
status: active
system_status: E2
hito: H1
---

# Meter

Recurso de combate medido en barras. En Godot vive en `PlayerMeter`; la capacidad y los **costos**
salen de `PlayerTuning`, pero las **ganancias** las trae cada fuente.

> [!important] Quien decide cuanto
> El meter que se GANA lo decide la fuente; el que se GASTA lo decide el jugador.
> `PlayerMeter` no lee ganancias de ningun lado: recibe el monto y lo suma
> (`gain_on_hit(bars)` / `gain_on_kill(bars)`). Antes leia `PlayerTuning`, y por eso todas las armas
> daban exactamente lo mismo por golpe. *(2026-07-28)*

## Ganancias — viven en la fuente

| Fuente | Knob |
|---|---|
| Golpe de arma | `WeaponTuning.meter_gain_on_hit` (por arma, en su `.tres`) |
| Kill con arma | `WeaponTuning.meter_gain_on_kill` (por arma) |
| Golpe del Brazo | `ArmTuning.meter_gain_on_hit` (ver [[Brazo]]) |
| Bloques de traversal | export de la escena del bloque |

Espada y Mazo arrancan los dos en `1.0` hit / `0.5` kill — los valores que ya tenian cuando la
ganancia era global, asi que el cambio no movio el balance. La palanca esta abierta pero sin usar:
el Mazo tiene `swing_time` mas largo que la Espada, o sea que a igual ganancia por golpe genera
meter mas lento. Si tienen que empatar, se sube el hit del Mazo.

## Costos — viven en `PlayerTuning` (grupo Meter)

| Gasto | Knob | Monto |
|---|---|---|
| Dash / dodge | `meter_dash_cost` | fraccion de barra |
| Ataque cargado | `meter_charged_cost` | 1 barra (× nivel en el Mazo, × descuento del sweet spot) |
| Sprint activo | `sprint_meter_drain_per_second` | fraccion del meter COMPLETO por segundo (ver [[Sprint]]) |
| Variante RT de un tap direccional | `SwordTuning.tap_x_meter_cost` | media barra, por arma (ver [[Taps Direccionales]]) |

Los cargados usan `spend_charged` (pide barras enteras y abre la kill window); los gestos puntuales
que cobran fracciones sin abrir esa ventana usan `spend_bars`.

## El meter button

> [!important] El boton se llama `meter_button`, no `sprint`
> No es el boton de correr: es el boton de **gastar meter**, y tiene **dos funciones**, una por
> mecanica madre. *(2026-07-28: renombrado desde `sprint`, nombre que describia solo la mitad de lo
> que hace.)*

| Funcion | Mecanica madre | Que hace |
|---|---|---|
| Sprint | Traversal | Sostenerlo moviendose sube el nivel de sprint (velocidad, salto, cadenas de pared). Drena meter mientras esta activo. Ver [[Sprint]] |
| Taps direccionales reforzados | Combate | Sostenerlo al ejecutar un tap direccional paga media barra y saca la variante fuerte: mas vueltas, Movers propios, proyectil y flash. Ver [[Taps Direccionales]] |

Lo que unifica las dos: apretarlo significa **"quemo recurso para ir mas fuerte"**, corras o pelees.
Por eso el mismo boton sirve para traversal y para combate, y por eso el nombre viejo confundia — un
jugador que lee "sprint" no espera que le cueste barra pegar.

> [!warning] Cobra dos veces y nadie lo tuneo asi
> Sostenerlo con input de movimiento paga el **drenaje del sprint** y el **costo del tap** a la vez:
> dos gastos por el mismo gesto de mano. Es coherente con lo que el boton significa, pero no esta
> tuneado como un costo unico. Si al jugarlo se siente caro, las salidas son descontarle al tap lo
> que ya cobro el sprint, o cobrar solo el mayor de los dos. *(2026-07-28)*

El sprint es el gasto nuevo y el unico **continuo**: los demas son pagos puntuales. Su costo se
expresa como fraccion del total y no en barras, asi subir `meter_max_bars` no abarata la carrera.
*(2026-07-28)*

> [!warning] Ningun cargado es gratis
> El Y cargado terrestre (el launcher) de Espada y Mazo salia gratis: era el unico cargado que no
> pagaba. Ahora cuesta 1 barra en las dos armas, y sin barra cae al tap normal. El gesto
> `tap atras + Y` del lock-on **sigue gratis**: es un tap, no un cargado. *(2026-07-28)*

## Preview de gasto en el HUD

Mientras un ataque esta cargado, el tramo de meter que va a consumir **late** sobre las barras.
*(2026-07-28)*

- El tramo se descuenta **desde el tope hacia abajo**: con 1.5 barras y un cargado de 1 late la
  mitad alta de la primera barra mas la segunda entera, y queda apagado el 0.5 con el que te vas a
  quedar. Se lee como "esto es lo que se va".
- Aparece recien al cruzar el umbral de carga, no en el press: por debajo del umbral soltar da un
  tap, y un tap es gratis.
- El color lo trae el arma (`WeaponBase.charge_glow_color`), asi el meter late del mismo tono que
  la hoja.
- El monto lo calcula **el arma** (`WeaponBase.charged_meter_cost`), unica que sabe si su cargado
  sale gratis, escala por nivel o lleva descuento. Casos vivos: cargando X con el Mazo en suelo el
  tramo crece de a una barra por nivel; soltando dentro del sweet spot de la Espada el tramo se
  **achica** en vivo (ese es el feedback que hace legible el sweet spot).

> [!bug] El modo de falla es que mienta
> `charged_meter_cost` (lo que el HUD promete) y `spend_charged` (lo que se cobra) son dos numeros
> distintos que tienen que coincidir. Si se separan, el HUD marca barras que no se gastan — o peor,
> se gastan sin aviso. Hay un assert en `combat_smoke_test.gd` que los ata.

## Futuro

- Capacidad hasta 5 barras.
- Dodge degradado sin meter.
- Perfect dodge genera meter.
- Habilidad suprema con barras llenas.

## Verificacion

Estado **E2** (bajo de E3 al cambiar la estructura de ganancias y sumar el gasto del sprint). Los
knobs existen y la direccion esta clara; falta iterar jugando. Lo que hay que sentir primero: el
meter paso de sobrar a ser un recurso peleado entre correr, dashear y lanzar. Los numeros
(`0.1`/s de sprint, 1 barra de launcher, 10 barras de capacidad en el `.tres` actual) no los probo
nadie todavia. *(2026-07-28)*

> [!warning] Tuning de test
> `player_tuning.tres` tiene `meter_max_bars = 10` y `meter_start_bars = 10.0`: arrancas con el
> meter lleno. Es comodo para probar cargados, pero no es el arranque real.

## Relacionado

- [[Combate]]
- [[Sprint]]
- [[Taps Direccionales]]
- [[Espada]]
- [[Mazo]]
- [[Brazo]]
