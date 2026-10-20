-- Tibia 5E: Quick Loot (Alt+Q no cliente envia "/quickloot").
-- Saqueia os corpos em volta do jogador (1 sqm), como no Tibia: os itens vao
-- para a mochila, o dinheiro tambem, e o corpo fica vazio.

local function isCorpse(item)
	if not item or not item.getId then return false end
	local itemType = ItemType(item:getId())
	if not itemType or not itemType:isContainer() or not item.getSize then return false end
	return itemType:isCorpse()
end

local function canLoot(player, corpse)
	local owner = corpse.getCorpseOwner and corpse:getCorpseOwner() or 0
	if not owner or owner == 0 then return true end
	if owner == player:getId() or owner == player:getGuid() then return true end
	local party = player:getParty()
	if party then
		local ownerPlayer = Player(owner)
		if ownerPlayer and ownerPlayer:getParty() == party then return true end
	end
	return false
end

local function describe(item)
	local count = item:getCount()
	if ItemType(item:getId()):isStackable() and count > 1 then
		return string.format("%d %s", count, item:getPluralName())
	end
	local article = item:getArticle()
	return (article ~= "" and (article .. " ") or "") .. item:getName()
end

local function lootContainer(player, container, looted, state)
	for index = container:getSize() - 1, 0, -1 do
		local item = container:getItem(index)
		if item then
			local text = describe(item)
			local result = item:moveTo(player)
			if result then
				looted[#looted + 1] = text
			else
				state.full = true
			end
		end
	end
end

local function quickLoot(player)
	local pos = player:getPosition()
	local looted, state, corpses, denied = {}, { full = false }, 0, 0
	for dx = -1, 1 do
		for dy = -1, 1 do
			local tile = Tile(Position(pos.x + dx, pos.y + dy, pos.z))
			if tile then
				for _, item in ipairs(tile:getItems() or {}) do
					if isCorpse(item) then
						if canLoot(player, item) then
							corpses = corpses + 1
							lootContainer(player, item, looted, state)
						else
							denied = denied + 1
						end
					end
				end
			end
		end
	end

	if corpses == 0 then
		player:sendCancelMessage(denied > 0 and "You are not the owner of this corpse." or "There is no corpse to loot nearby.")
		return
	end
	if #looted == 0 then
		player:sendTextMessage(MESSAGE_INFO_DESCR, state.full and "You have no room to loot anything." or "Nothing to loot.")
		return
	end
	player:sendTextMessage(MESSAGE_INFO_DESCR, "You looted: " .. table.concat(looted, ", ") .. ".")
	if state.full then
		player:sendTextMessage(MESSAGE_STATUS_SMALL, "Some items could not be looted: you have no room or capacity.")
	end
end

local cooldown = {}
local action = TalkAction("/quickloot")
action:onSay(function(player)
	local now = os.mtime()
	if (cooldown[player:getId()] or 0) > now then return false end
	cooldown[player:getId()] = now + 400
	quickLoot(player)
	return false
end)
action:register()
