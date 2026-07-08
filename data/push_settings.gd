class_name PushSettings extends Resource
## Parametros de un empujon aereo en arco (rama espera del combo aereo). Lo define QUIEN
## ataca, no el enemigo (igual que StunSettings): cada fuente de push lleva su propio arco,
## asi cada arma/ataque puede empujar distinto. Instancias .tres/embebidas viven en data/.

@export var horizontal_speed := 8.0   # alcance: velocidad horizontal constante del arco
@export var up_speed := 6.0           # altura: impulso vertical inicial (subida del arco)
@export var gravity := -20.0          # cierre del arco: mas negativo = cae mas rapido
