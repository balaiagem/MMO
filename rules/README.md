# Rules kernel — tested separately, not enabled in live combat

`core.lua` is a pure Lua module compatible with Lua 5.1 and 5.5. Callers inject a server RNG and monotonically increasing server milliseconds. No client-provided rolls or timestamps may reach these APIs.

Implemented: ability modifiers, proficiency levels 1–20, array/point-buy validation, advantage cancellation, attack/save distinction, critical dice, resistance/vulnerability, concentration DC/save, full-caster and Pact Magic slot tables, slot spending, Fighter Extra Attack counts, cantrip scaling, death-save transitions, independent action/bonus/reaction/movement budgets.

This is not a spell engine, character-creation flow, complete condition engine, death system or class implementation. It does not yet enforce proficiency ownership, prerequisites, concentration replacement, spell components, rests, incapacitation, conditions, line of sight, reactions, or atomic world transactions. TFS combat is unchanged.

Implemented real-time adaptation: an actor's authoritative epoch defines half-open 6000 ms cycles. Each boundary refreshes one action, bonus action and reaction. Unused budgets expire. Attack grants consume one action and expire with the cycle. Five feet per tile may be charged by the caller; movement pacing and diagonal collision still belong to the engine.

Before integration: define initiative/ordering for simultaneous events, reaction windows and Shield rollback; commit validated spell costs and effects atomically; cancel concentration on incapacitation; apply saves per distinct damage source; prevent latency/reconnect budget reset. These are remaining work, not behavior supplied by this kernel.

Tests use deterministic die fixtures and cover boundary behavior. Run `python tools/test-rules.py` after installing Lupa into tools/python, or run `lua tests/rules.lua` from the project root.
