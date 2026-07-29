---
title: Taps Direccionales
tags:
  - egoist
  - gameplay
  - sistema
  - combate
  - input
status: active
system_status: E2
hito: H1
---

# Taps Direccionales

Los taps direccionales son gestos de combate relativos al objetivo de lock-on. Un tap hacia adelante o atras abre una ventana breve; si X o Y llega dentro de esa ventana, el arma equipada puede reemplazar el ataque normal por un especial propio.

## Contrato de input

- Requieren lock-on activo. Sin objetivo bloqueado, X e Y siguen su ruta normal.
- La direccion se mide en el plano horizontal contra el vector Player -> objetivo: adelante se acerca al objetivo y atras se aleja.
- El gesto debe empezar desde input de movimiento neutral. Solo se registra la primera direccion al salir de neutral; mantener o girar el stick no abre otra ventana.
- La ventana se mantiene por slot y direccion: adelante/atras para X y adelante/atras para Y son independientes.
- Pulsar X o Y dentro de la ventana la consume una vez. El especial entra como ataque normal y no espera el release. Por defecto no gasta meter; cada arma puede documentar una variante opcional de ese gesto que cobre meter, como la Espada con RT + X.
- En los taps X de Espada, mantener el boton despues del press alimenta la carga normal. El tap sale de inmediato, pero el cargado queda retenido hasta que finalicen la coreografia y el Mover del gesto; no puede cancelar el movimiento a mitad.
- Un valor de ventana `0` desactiva ese gesto para el arma.

## Flujo tecnico

`PlayerCombat._track_lock_direction_tap()` corre al procesar input y por frame. Lee el input de locomocion, arma el tap desde neutral y guarda el vencimiento de cada direccion. Al presionar ataque, intenta el especial antes de llamar al `InputBuffer` normal:

```text
neutral -> direccion hacia/contra target -> ventana abierta
ventana + X/Y -> hook del WeaponBase -> especial o tap normal
```

Las armas usan hooks opcionales de `WeaponBase`; las que no los sobreescriben devuelven `false` y no cambian su comportamiento:

| Slot | Adelante | Atras |
|---|---|---|
| Y | `try_lock_forward_y_push()` | `try_lock_back_y_launcher()` |
| X | `try_lock_forward_x_static_spin()` | `try_lock_back_x_retreat()` |

Cada hook tiene su getter de ventana. La implementacion generica vive en `player/player_combat.gd`; la personalidad del movimiento vive en el arma y su tuning.

## Ejemplo: Espada

`SwordTuning` define una ventana por gesto. La Espada las usa asi:

| Gesto | Suelo | Aire |
|---|---|---|
| Tap adelante + X | Vueltas puras, sin proyectil. RT usa mas vueltas. | Vueltas sin proyectil. RT usa Floaters propios de Player/Enemy, separados de la variante normal. |
| Tap atras + X | Retroceso; RT dispara y define su launcher terrestre. | Normal: retroceso corto sin proyectil. RT: retroceso largo, Floaters propios y proyectil con launcher aereo independiente. |
| Tap adelante + Y | Vuelta final que avanza al Player con `tap_forward_y_player_mover`, sin push. | Misma vuelta y avance; arma `PushSettings` para el enemigo. |
| Tap atras + Y | Launcher sin barra que mueve solo al Enemy con `tap_back_y_enemy_mover`. | Hachazo que inicia el plunge de Player y objetivos conectados. |

Los knobs son `tap_forward_x_window`, `tap_back_x_window`, `tap_forward_y_window` y `tap_back_y_window`. Cada gesto lleva sus propios perfiles de desplazamiento y hang, separados de los del resto de los golpes; la lista completa esta en [[Espada]] y la primitiva en [[Mover y Floater]].

## Como agregar un gesto a un arma

1. Agregar el campo de ventana al `WeaponTuning` especifico del arma y dejarlo en `0` si debe permanecer apagado por defecto. Va en su propio grupo del gesto, con los perfiles del golpe en subgrupos por tramo; la convencion esta en [[Armas]].
2. Sobrescribir el getter y el hook adecuado en la clase del arma. El hook debe devolver `true` solo si inicio la rutina especial.
3. Iniciar el movimiento, hitboxes y efectos desde la rutina del arma. `PlayerCombat` no decide coreografia.
4. Probar sin lock-on, con stick sostenido, cambiando rapidamente de direccion y venciendo la ventana: todos deben caer al ataque normal.

## Relacionado

- [[Combate]]
- [[Input Feel]]
- [[Espada]]
- [[Mover y Floater]]
- [[Lock On]]
