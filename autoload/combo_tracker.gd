extends Node
## Estado global de combo (ex ComboTracker.cs). Autoload: ComboTracker.
## Global por diseño: cualquier arma lee "vas N hits" para decidir su potencia.

signal hit_registered(count: int)

var hit_count := 0
