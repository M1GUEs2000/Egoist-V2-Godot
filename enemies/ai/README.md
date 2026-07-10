IA de enemigos: `GroundedEnemy` conserva la FSM como fallback seguro y ya tiene backend
dual `AIBackend.FSM / AIBackend.LIMBO`. Decision tomada (2026-07-08): se adopta
LimboAI (BT + HSM) desde el inicio, no "migrar despues"; el addon ya esta instalado en
`addons/limboai/`.

El port code-only esta preparado para validacion en Godot:

- `EnemyAIBlackboard`: estado compartido e intent contract.
- `EnemyLimboTreeBuilder`: arma por codigo el BehaviorTree equivalente al selector actual.
- `tasks/*.gd`: hojas `BTAction` / `BTCondition` pequenas que llaman metodos publicos del
  agente.
- `grounded_enemy.tscn`: trae un `BTPlayer` manual. El default sigue en FSM hasta probarlo
  en editor/headless.

El plano construible vive en `enemies/ai_spec/*.yaml`. Ver `obsidian/Gameplay/IA/IA.md`
para el detalle de la decision y el estado del port.
