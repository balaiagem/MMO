-- Tibia 5E: contagem de abates para as quests de Rookgaard
-- (dialogos em data/npc/lib/rook_quests.lua).

local KILL_QUESTS = {
	["cave rat"] = { title = "Al Dee's Stolen Tools", status = 96101, counter = 96102, need = 10, plural = "cave rats", npc = "Al Dee" },
}

local questKill = CreatureEvent("RookQuestKill")
questKill:type("kill")
questKill:onKill(function(player, target)
	if not player or not player.isPlayer or not player:isPlayer() then
		return true
	end
	if not target or not target.isMonster or not target:isMonster() then
		return true
	end

	local quest = KILL_QUESTS[string.lower(target:getName())]
	if not quest or player:getStorageValue(quest.status) ~= 1 then
		return true
	end

	local count = math.max(0, player:getStorageValue(quest.counter))
	if count >= quest.need then
		return true
	end

	count = count + 1
	player:setStorageValue(quest.counter, count)
	if count >= quest.need then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, string.format("%s: %d/%d %s. Return to %s.", quest.title, count, quest.need, quest.plural, quest.npc))
	else
		player:sendTextMessage(MESSAGE_STATUS_DEFAULT, string.format("%s: %d/%d %s.", quest.title, count, quest.need, quest.plural))
	end
	return true
end)
questKill:register()

local questLogin = CreatureEvent("RookQuestLogin")
questLogin:type("login")
questLogin:onLogin(function(player)
	player:registerEvent("RookQuestKill")
	return true
end)
questLogin:register()
