-- Pure, server-side SRD 5.1 rules primitives. No network or engine dependencies.
-- RNG and monotonic time must come from the authoritative server, never a packet.
-- Integrated combat adapter: world/content/dnd_combat.lua. Scope: docs/COMBAT-5E.md.
local R = {}
local function integer(n, low, high)
    assert(type(n) == 'number' and n == math.floor(n) and n >= low and n <= high, 'out of range integer')
    return n
end
function R.modifier(score) return math.floor((integer(score, 1, 30) - 10) / 2) end
function R.proficiency(level) return 2 + math.floor((integer(level, 1, 20) - 1) / 4) end
function R.roll(sides, rng) return integer(rng(integer(sides, 2, 100)), 1, sides) end
function R.d20(rng, advantage, disadvantage)
    local first = R.roll(20, rng)
    if (not not advantage) == (not not disadvantage) then return first, { first } end
    local second = R.roll(20, rng)
    return advantage and math.max(first, second) or math.min(first, second), { first, second }
end
function R.save(dc, bonus, rng, advantage, disadvantage)
    local roll, dice = R.d20(rng, advantage, disadvantage)
    -- Ordinary saves have no automatic success/failure on 20/1.
    return { success = roll + bonus >= dc, total = roll + bonus, dice = dice }
end
function R.attack(ac, bonus, rng, advantage, disadvantage)
    local roll, dice = R.d20(rng, advantage, disadvantage)
    return { hit = roll == 20 or (roll ~= 1 and roll + bonus >= ac),
        critical = roll == 20, total = roll + bonus, natural = roll, dice = dice }
end
function R.damage(count, sides, modifier, critical, rng)
    integer(count, 1, 100)
    local total, dice = modifier, {}
    for _ = 1, count * (critical and 2 or 1) do
        local value = R.roll(sides, rng); total = total + value; dice[#dice + 1] = value
    end
    return math.max(0, total), dice
end
function R.mitigate(amount, immune, resistant, vulnerable)
    integer(amount, 0, 1000000)
    if immune then return 0 end
    if resistant then amount = math.floor(amount / 2) end
    if vulnerable then amount = amount * 2 end
    return amount
end
function R.concentration(damage, conSaveBonus, rng, advantage, disadvantage)
    integer(damage, 1, 1000000)
    local dc = math.max(10, math.floor(damage / 2))
    local result = R.save(dc, conSaveBonus, rng, advantage, disadvantage)
    result.dc = dc
    return result
end
function R.spellDC(level, ability) return 8 + R.proficiency(level) + R.modifier(ability) end
function R.spellAttack(level, ability) return R.proficiency(level) + R.modifier(ability) end
local costs = { [8]=0, [9]=1, [10]=2, [11]=3, [12]=4, [13]=5, [14]=7, [15]=9 }
function R.abilityScores(scores, method)
    if type(scores) ~= 'table' or #scores ~= 6 then return false, 'six scores required' end
    local sorted, spent = {}, 0
    for i = 1, 6 do
        if not costs[scores[i]] then return false, 'scores must be integers from 8 to 15' end
        sorted[i], spent = scores[i], spent + costs[scores[i]]
    end
    if method == 'point-buy' then return spent <= 27, spent end
    if method ~= 'standard-array' then return false, 'unknown method' end
    table.sort(sorted)
    local expected = {8,10,12,13,14,15}
    for i = 1, 6 do if sorted[i] ~= expected[i] then return false, 'invalid standard array' end end
    return true
end
local fullCaster = {
    {2},{3},{4,2},{4,3},{4,3,2},{4,3,3},{4,3,3,1},{4,3,3,2},
    {4,3,3,3,1},{4,3,3,3,2},{4,3,3,3,2,1},{4,3,3,3,2,1},
    {4,3,3,3,2,1,1},{4,3,3,3,2,1,1},{4,3,3,3,2,1,1,1},
    {4,3,3,3,2,1,1,1},{4,3,3,3,2,1,1,1,1},{4,3,3,3,3,1,1,1,1},
    {4,3,3,3,3,2,1,1,1},{4,3,3,3,3,2,2,1,1}
}
function R.fullCasterSlots(level)
    local copy = {}; for i, value in ipairs(fullCaster[integer(level, 1, 20)]) do copy[i] = value end
    return copy
end
function R.effectiveSlotLevel(spellLevel, selectedLevel)
    integer(spellLevel, 1, 9); integer(selectedLevel, 1, 9)
    return math.max(spellLevel, selectedLevel)
end
function R.resolveSlotLevel(slots, spellLevel, selectedLevel)
    local preferred = R.effectiveSlotLevel(spellLevel, selectedLevel)
    for slotLevel = preferred, spellLevel, -1 do
        if (slots[slotLevel] or 0) > 0 then return slotLevel end
    end
    return nil
end
function R.consumeSlot(slots, spellLevel, selectedLevel)
    local slotLevel = R.resolveSlotLevel(slots, spellLevel, selectedLevel)
    if not slotLevel then return false end
    slots[slotLevel] = slots[slotLevel] - 1
    return true, slotLevel
end
function R.pactSlots(level)
    integer(level, 1, 20)
    return { count = level == 1 and 1 or (level < 11 and 2 or (level < 17 and 3 or 4)),
        level = math.min(5, math.ceil(level / 2)) }
end
function R.fighterAttacks(level)
    integer(level, 1, 20)
    return level < 5 and 1 or (level < 11 and 2 or (level < 20 and 3 or 4))
end
function R.cantripDice(level)
    integer(level, 1, 20)
    return level < 5 and 1 or (level < 11 and 2 or (level < 17 and 3 or 4))
end
function R.deathSave(state, rng)
    if state.dead or state.stable or state.hp > 0 then return false end
    local roll = R.roll(20, rng)
    if roll == 20 then state.hp, state.successes, state.failures = 1, 0, 0
    elseif roll < 10 then state.failures = state.failures + (roll == 1 and 2 or 1)
    else state.successes = state.successes + 1 end
    if state.failures >= 3 then state.dead = true end
    if state.successes >= 3 then state.stable = true; state.successes, state.failures = 0, 0 end
    return roll
end

-- Real-time adaptation: per-actor six-second cycles; server timestamp only.
-- Budgets do not accumulate, even after idle time or a scheduling delay.
function R.newEconomy(now)
    integer(now, 0, 9007199254740991)
    return { epoch = now, cycle = 0, last = now, action = true, bonus = true,
        reaction = true, attacks = 0, feet = 0, extraActions = 0 }
end
-- Encounter turns are advanced by the combat adapter, never by wall-clock time.
function R.newTurnEconomy(now)
    local e = R.newEconomy(now)
    e.turnBased = true
    return e
end
function R.startTurn(e)
    e.turnBased = true
    e.action, e.bonus, e.reaction, e.attacks, e.feet = true, true, true, 0, 0
    e.extraActions, e.bonusSpell, e.nonCantripActionSpell = 0, false, false
    e.turn = (e.turn or 0) + 1
end
function R.refresh(e, now)
    integer(now, e.last, 9007199254740991); e.last = now
    local cycle = math.floor((now - e.epoch) / 6000)
    if cycle > e.cycle then
        e.cycle, e.action, e.bonus, e.reaction, e.attacks, e.feet = cycle, true, true, true, 0, 0
        e.extraActions, e.bonusSpell, e.nonCantripActionSpell = 0, false, false
    end
end
function R.spend(e, budget, now)
    assert(budget == 'action' or budget == 'bonus' or budget == 'reaction', 'invalid budget')
    if not e.turnBased then R.refresh(e, now) end
    if not e[budget] then return false end
    if budget == 'action' and (e.extraActions or 0)>0 then
        e.extraActions=e.extraActions-1
    else e[budget]=false end
    return true
end
function R.grantAction(e)
    if e.action then e.extraActions=(e.extraActions or 0)+1 else e.action=true end
end
function R.canCastSpell(e, isBonus, circle)
    if isBonus then return not e.nonCantripActionSpell end
    return not e.bonusSpell or circle==0
end
function R.recordSpell(e, isBonus, circle)
    if isBonus then e.bonusSpell=true elseif circle>0 then e.nonCantripActionSpell=true end
end
function R.beginAttack(e, count, now)
    integer(count, 1, 4)
    if not R.spend(e, 'action', now) then return false end
    e.attacks = count; return true
end
function R.spendAttack(e, now)
    if not e.turnBased then R.refresh(e, now) end
    if e.attacks < 1 then return false end
    e.attacks = e.attacks - 1; return true
end
function R.move(e, feet, speed, now)
    integer(feet, 1, 1000); integer(speed, 0, 1000); if not e.turnBased then R.refresh(e, now) end
    if e.feet + feet > speed then return false end
    e.feet = e.feet + feet; return true
end
return R
