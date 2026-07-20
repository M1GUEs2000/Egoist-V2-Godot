---
title: Plan Autoridad Vertical
tags:
  - egoist
  - godot
  - combate
  - plan
status: active
system_status: E0
hito: H1
---

# Plan Autoridad Vertical

Consolidacion del control de la velocidad vertical del jugador en combate aereo. Hoy siete sistemas la tocan (air-hit-stall, whiff penalty, float/fall del launcher, hover, arm freeze, air charge fall control, plunge) mas los moves que la setean directo (smash X Mazo, caida Y Mazo, air_hop, doble salto, bop del dash). La prioridad entre ellos es implicita y hay choques de feel reales. El traversal no se toca: esta bien.

## Diagnostico (2026-07-19)

### Choques confirmados

1. **El stall apaga el smash aereo X del Mazo.** El smash setea la vertical una vez (`mace.gd`, `air_smash_fall_speed`); al conectar, `register_air_hit_stall` clampea la vertical a `[0, air_stall_max_rise]` (`player_launcher.gd`) y el martillazo se frena en seco a mitad de caida. El flag de cargado solo exime el corte de momentum horizontal, no ese clamp. El plunge de la Espada no lo sufre solo porque re-fuerza su velocidad cada frame.
2. **El whiff penalty pisa el float del launcher.** Prioridad fija en `gravity_scale()`: stall > whiff > float > fall. Errar un golpe durante el float post-launch aplica gravedad 1.6 y mata la ventana que el launcher compro.
3. **Hover no es hover.** `hover()` escribe en `_air_stall_until`: comparte timer y gravedad (0.15) con el stall, cae despacio en vez de flotar, y el doble salto lo mata junto con el stall.

### Redundancias

- "Bajar rapido como move" x3: plunge Espada (constante, cancelable por rebote), smash X Mazo (inicial + gravedad), caida Y Mazo (diagonal + loop de contacto). Tres cancels y tres aterrizajes distintos.
- "Conectar en el aire frena la caida" x3: air-hit-stall (armas), arm freeze (Brazo), air charge fall control (cargas). Un Y aereo del Mazo que conecta activa dos a la vez.
- Vocabulario: stall, float, hover, freeze, fall control, whiff fall, plunge — siete nombres para variantes de "cuanto caes ahora".

## Objetivo

Una sola autoridad vertical con prioridad explicita, un solo verbo de "caida de move" y nombres que no se pisen. Cero cambio de mecanicas: mismo comportamiento buscado, menos duenos.

Prioridad objetivo (de mayor a menor):

```text
1. plunge / caida de move (compromiso)
2. arm freeze (pausa con restauracion)
3. hover (gravedad 0 real, timer propio)
4. air-hit-stall (gravedad baja + clamp)
5. float del launcher        <- gana al whiff (cambio del choque 2)
6. whiff penalty
7. fall suave del launcher
8. gravedad normal
```

## Fases

### F1 — Choques puntuales (chico, alto impacto)

- [ ] El clamp del stall (`register_air_hit_stall`) no aplica si hay una caida de move activa: gate por `is_plunging()` del player o flag equivalente del arma. Arregla el smash X del Mazo sin tocar su codigo.
- [ ] Reordenar `gravity_scale()`: `launcher_float` por encima de `aerial_whiff_fall`. Un knob nuevo no hace falta; es solo orden.
- Salida: probar jugando smash aereo X del Mazo (debe seguir cayendo al conectar) y launcher Y + whiff (debe conservar el float).

### F2 — Hover propio

- [ ] `hover()` gana timer propio (`_hover_until`) y gravedad propia (`hover_gravity`, default 0.0, tuneable en PlayerTuning con `##`).
- [ ] Decidir si el doble salto lo corta (hoy corta el stall; el hover existe justamente para gastarlo — probablemente NO debe cortarlo antes de tiempo, solo consumirse al saltar).
- Salida: sweet spot de Espada y Y aereo del Mazo flotan de verdad; el resto del feel identico.

### F3 — Un solo verbo de caida de move

- [ ] `Player.plunge(down_speed, accelerating := false)`: el modo acelerado suma gravedad sobre la velocidad inicial (para el Mazo); el constante queda como esta (Espada).
- [ ] Smash aereo X del Mazo migra a `plunge(air_smash_fall_speed, true)`.
- [ ] Evaluar la caida Y del Mazo: su loop de contacto fisico es identidad del move (intercepta), puede quedarse — pero su vertical pasa por plunge para heredar prioridad y cancels. Si complica, se documenta como excepcion consciente y no se fuerza.
- [ ] Cancels unificados: rebote en enemigo, stun, launch, bump, dodge — los que ya tiene el plunge. Revisar cuales aplican al Mazo sin romper su rama de rebote propia.
- Salida: los tres moves descendentes pasan por un unico punto con una unica tabla de cancels.

### F4 — Air charge fall control: decidir

- [ ] Jugar con y sin (`air_charge_fall_reduction_steps = [0.0]`) y decidir si se percibe.
- [ ] Si no se percibe: eliminar modulo y knobs, el stall ya cubre el caso.
- [ ] Si se percibe: dejarlo, pero renombrar knobs para que no colisionen con el vocabulario del stall y documentar en [[Combate]] cuando gana cada uno.

### F5 — Documentacion y cierre

- [ ] Actualizar [[Combate]] con la tabla de prioridad vertical final (fuente unica de verdad del feel aereo).
- [ ] Barrer nombres en codigo y boveda: un termino por concepto (stall, hover, freeze, plunge, float — cada uno una sola cosa).
- [ ] Esta nota pasa a registrar lo decidido (o se absorbe en [[Combate]] y se borra).

## Reglas

- Una fase por sesion como maximo; cada una se aprueba jugando antes de seguir (el feel manda).
- Ningun knob pierde su valor actual: los defaults nuevos replican el comportamiento aprobado.
- Verificacion por fase: `--import` limpio + prueba jugando de los moves tocados.

## Relacionado

- [[Combate]]
- [[Espada]]
- [[Mazo]]
- [[Brazo]]
- [[Rebote en Enemigos]]
- [[tareas]]
