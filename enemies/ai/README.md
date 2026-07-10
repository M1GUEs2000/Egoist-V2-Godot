IA de enemigos: hoy `GroundedEnemy` corre una FSM (priority-selector escrito a mano,
enum `AIState` con 15 estados). Decision tomada (2026-07-08): se adopta LimboAI (BT + HSM)
desde el inicio, no "migrar despues" — el addon ya esta instalado en `addons/limboai/`.
El plano construible vive en `enemies/ai_spec/*.yaml`. Ver `obsidian/Gameplay/IA/IA.md`
para el detalle de la decision y el estado del port.
