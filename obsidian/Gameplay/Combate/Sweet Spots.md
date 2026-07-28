---
title: Sweet Spots
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

# Sweet Spots

Un Sweet Spot es una ventana de timing dentro de una carga. Soltar el ataque cargado dentro de esa ventana arma el flag `WeaponBase.sweet_spot`; cada arma decide si ese flag cambia su coste, trayectoria o efecto. No es un nivel de carga: seguir sosteniendo puede dejar pasar la ventana.

## Regla y tuning

`WeaponTuning.in_sweet_spot(held)` acepta el intervalo cerrado:

```text
[sweet_spot_start, sweet_spot_start + sweet_spot_duration]
```

Ambos valores se cuentan desde el press, no desde el `hold_threshold`. `sweet_spot_duration <= 0` desactiva el sistema para esa arma.

| Knob | Funcion |
|---|---|
| `sweet_spot_start` | Segundo desde el press en que abre la ventana. |
| `sweet_spot_duration` | Duracion de la ventana. |
| `sweet_spot_meter_discount` | Descuento del coste de meter del cargado valido. |
| `sweet_spot_particles_*` | Aura sobre la hoja que anuncia visualmente la ventana. |

Mientras se carga, `PlayerCombat` muestra el aura solo cuando la ventana esta abierta. Al disparar el hold, lee la duracion real sostenida, llama `weapon.arm_sweet_spot(...)` y luego inicia el cargado. Un cargado bufferizado no gana tiempo extra por esperar su ejecucion.

## Ejemplo: Espada

La Espada usa `sweet_spot_start = 0.4 s`; conserva la duracion y el descuento base de `WeaponTuning` si el `.tres` no los sobreescribe.

Su X cargado consume el flag de dos maneras:

- Paga el coste de meter escalado con `tuning.meter_cost_scale(sweet_spot)`.
- Si el dash conecta, el Sweet Spot encadena el launcher terrestre sin gastar otra barra.
- En aire y con lock-on, el dash de Sweet Spot puede orientar su trayectoria hacia el objetivo en los tres ejes; el cargado normal conserva su rumbo recto.

Actualmente `Sword._hold_y()` no lee `sweet_spot`, por lo que el Y cargado no tiene modificador de Sweet Spot implementado. Cualquier comportamiento adicional para Y sigue siendo diseno pendiente y debe añadirse de forma explicita en la rutina de la Espada.

## Como implementar un efecto

1. Definir la ventana y el feedback visual en el `WeaponTuning` del arma.
2. En la rutina `hold`, capturar `sweet_spot` antes de iniciar operaciones asincronas o gasto de meter.
3. Aplicar el efecto en la misma ruta del cargado: coste, perfil Mover/Floater, hitbox o follow-up. No recalcular el tiempo de hold dentro del arma.
4. Mantener un cargado normal funcional fuera de la ventana y con meter insuficiente.

Patron minimo:

```gdscript
func _hold_x() -> void:
    var is_sweet := sweet_spot
    var cost_scale := tuning.meter_cost_scale(is_sweet)
    if _player.meter.spend_charged(1, true, cost_scale):
        _start_charged_attack(is_sweet)
```

## Relacionado

- [[Combate]]
- [[Input Feel]]
- [[Meter]]
- [[Espada]]
