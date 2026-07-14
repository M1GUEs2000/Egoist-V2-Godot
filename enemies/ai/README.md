IA de enemigos: el motor de decision es LimboAI (BT + HSM), addon en `addons/limboai/`.
Es el backend unico — todo comportamiento nuevo se escribe como hoja del arbol. La FSM de
`GroundedEnemy` (`use_simple_fsm`) queda solo como fallback si el GDExtension no carga, y
esta pendiente de retirar.

- `EnemyAIBlackboard`: estado compartido e intent contract (la decision emite intent, la
  locomocion lo ejecuta).
- `EnemyLimboTreeBuilder`: arma por codigo el BehaviorTree de combate.
- `tasks/*.gd`: hojas `BTAction` / `BTCondition` pequenas que llaman metodos publicos del
  agente (`limbo_*`).
- `grounded_enemy.tscn`: trae el `BTPlayer` en modo manual, tickeado desde `_physics_process`.

El plano construible vive en `enemies/ai_spec/*.yaml`. Ver `obsidian/Gameplay/IA/IA.md`.
