-- Tibia 5E: comida, fome e a cadeia do pao (portado do TFS, data/scripts/actions/others).
--
-- Fome: cada personagem tem uma reserva de saciedade (segundos de jogo online).
-- Comer enche a reserva (valores do Tibia x5). Quando a reserva acaba o personagem
-- fica com fome e ganha 1 nivel de exaustao (D&D). Comer de novo tira essa exaustao.
--
-- Pao: foice no trigo maduro -> feixe de trigo; feixe no moinho (millstone) -> farinha;
-- encher balde/frasco na fonte, poco ou barril de agua; farinha no recipiente com agua ->
-- massa; massa no forno -> pao.

local SATIETY = 95210        -- segundos de saciedade restantes
local HUNGER_FLAG = 95211    -- 1 = a fome aplicou 1 nivel de exaustao
local HUNGER_WARNED = 95212  -- 1 = ja avisou que esta ficando com fome
local EXHAUSTION = 95101
local FOOD_SCALE = 5          -- Tibia: segundos = valor x 12; aqui x 12 x 5
local MAX_SATIETY = 3 * 3600  -- "You are full."
local START_SATIETY = 3600
local TICK = 60

local foods = {
	[3250] = {5, "Crunch."}, [3577] = {15, "Munch."}, [3578] = {12, "Munch."}, [3579] = {10, "Mmmm."},
	[3580] = {17, "Munch."}, [3581] = {4, "Gulp."}, [3582] = {30, "Chomp."}, [3583] = {60, "Chomp."},
	[3584] = {5, "Yum."}, [3585] = {6, "Yum."}, [3586] = {13, "Yum."}, [3587] = {8, "Yum."},
	[3588] = {1, "Yum."}, [3589] = {18, "Slurp."}, [3590] = {1, "Yum."}, [3591] = {2, "Yum."},
	[3592] = {9, "Yum."}, [3593] = {20, "Yum."}, [3594] = {17, "Munch."}, [3595] = {5, "Crunch."},
	[3596] = {6, "Munch."}, [3597] = {9, "Crunch."}, [3598] = {2, "Crunch."}, [3599] = {2, "Munch."},
	[3600] = {10, "Crunch."}, [3601] = {3, "Crunch."}, [3602] = {8, "Crunch."}, [3606] = {6, "Gulp."},
	[3607] = {9, "Smack."}, [3723] = {9, "Munch."}, [3724] = {4, "Munch."}, [3725] = {22, "Munch."},
	[3726] = {30, "Munch."}, [3727] = {9, "Munch."}, [3728] = {6, "Munch."}, [3729] = {12, "Munch."},
	[3730] = {3, "Munch."}, [3731] = {36, "Munch."}, [3732] = {5, "Munch."}, [5096] = {4, "Yum."},
	[5678] = {8, "Gulp."}, [6277] = {10, "Mmmm."}, [6278] = {15, "Mmmm."}, [6279] = {15, "Mmmm."},
	[6392] = {12, "Mmmm."}, [6393] = {15, "Mmmm."}, [6500] = {20, "Mmmm."}, [6569] = {1, "Mmmm."},
	[6574] = {5, "Mmmm."}, [7158] = {15, "Munch."}, [7159] = {13, "Munch."}, [836] = {4, "Crunch."},
	[841] = {4, "Crunch."}, [901] = {60, "Munch."}, [169] = {9, "Urgh."}, [8010] = {10, "Gulp."},
	[8011] = {5, "Yum."}, [8012] = {1, "Yum."}, [8013] = {1, "Urgh."}, [8014] = {7, "Munch."},
	[8015] = {5, "Crunch."}, [8017] = {5, "Munch."}, [8019] = {11, "Yum."}, [8197] = {5, "Crunch."},
	[40003] = {6, "Gulp."},
}

local function satiety(player)
	return math.max(0, player:getStorageValue(SATIETY))
end

local function exhaustion(player)
	return math.max(0, player:getStorageValue(EXHAUSTION))
end

local function setHungry(player, hungry)
	local flagged = player:getStorageValue(HUNGER_FLAG) == 1
	if hungry and not flagged then
		player:setStorageValue(HUNGER_FLAG, 1)
		player:setStorageValue(EXHAUSTION, math.min(6, exhaustion(player) + 1))
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You are hungry! Eat something. (Exaust\227o +1)")
		player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, string.format("[5E] Fome: exaust\227o %d. Coma algo para se recuperar.", exhaustion(player)))
	elseif not hungry and flagged then
		player:setStorageValue(HUNGER_FLAG, 0)
		player:setStorageValue(EXHAUSTION, math.max(0, exhaustion(player) - 1))
		player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, string.format("[5E] Voc\234 n\227o est\225 mais com fome. Exaust\227o %d.", exhaustion(player)))
	end
end

-- Comer -----------------------------------------------------------------------
local food = Action()
food:onUse(function(player, item)
	local entry = foods[item:getId()]
	if not entry then return false end
	local gain = entry[1] * 12 * FOOD_SCALE
	local current = satiety(player)
	if current + gain > MAX_SATIETY and current > MAX_SATIETY - 60 then
		player:sendTextMessage(MESSAGE_STATUS_SMALL, "You are full.")
		return true
	end
	player:setStorageValue(SATIETY, math.min(MAX_SATIETY, current + gain))
	player:setStorageValue(HUNGER_WARNED, 0)
	player:say(entry[2], TALKTYPE_MONSTER_SAY)
	item:remove(1)
	setHungry(player, false)
	return true
end)
local foodIds = {}
for id in pairs(foods) do
	local itemType = ItemType(id)
	if itemType and itemType:getId() ~= 0 then foodIds[#foodIds + 1] = id end
end
food:id(table.unpack(foodIds))
food:register()

-- Relogio da fome (so conta enquanto o personagem esta online).
local hungerTick = GlobalEvent("DndHungerTick")
hungerTick:interval(TICK * 1000)
hungerTick:onThink(function()
	for _, player in ipairs(Game.getPlayers()) do
		if player:getStorageValue(95000) == 1 and not player:getGroup():getAccess() then
			local left = math.max(0, satiety(player) - TICK)
			player:setStorageValue(SATIETY, left)
			if left == 0 then
				setHungry(player, true)
			elseif left <= 300 and player:getStorageValue(HUNGER_WARNED) ~= 1 then
				player:setStorageValue(HUNGER_WARNED, 1)
				player:sendTextMessage(MESSAGE_STATUS_SMALL, "You are getting hungry.")
			end
		end
	end
	return true
end)
hungerTick:register()

local hungerLogin = CreatureEvent("DndHungerLogin")
hungerLogin:type("login")
hungerLogin:onLogin(function(player)
	if player:getStorageValue(SATIETY) < 0 then player:setStorageValue(SATIETY, START_SATIETY) end
	if satiety(player) == 0 and player:getStorageValue(HUNGER_FLAG) == 1 then
		player:sendTextMessage(MESSAGE_STATUS_SMALL, "You are hungry.")
	end
	return true
end)
hungerLogin:register()

-- Liquidos: encher na fonte/barril/poco, beber, despejar, passar de um para outro.
local fluidContainers = { 2524, 2873, 2874, 2875, 2876, 2877, 2879, 2880, 2881, 2882, 2885, 2893, 2901, 2902, 2903, 2904, 3477, 3478, 3479, 3480 }
local isFluidContainerId = {}
for _, id in ipairs(fluidContainers) do isFluidContainerId[id] = true end

local drunk = Condition(CONDITION_DRUNK)
drunk:setParameter(CONDITION_PARAM_TICKS, 60000)

local fluidMessage = {
	[FLUID_BEER] = "Aah...", [FLUID_SLIME] = "Urgh!", [FLUID_LEMONADE] = "Mmmh.", [FLUID_MANA] = "Aaaah...",
	[FLUID_LIFE] = "Aaaah...", [FLUID_OIL] = "Urgh!", [FLUID_URINE] = "Urgh!", [FLUID_WINE] = "Aah...",
	[FLUID_MUD] = "Urgh!", [FLUID_RUM] = "Aah...", [FLUID_MEAD] = "Aaaah...", [FLUID_MILK] = "Mmmh.",
}

local function isItem(thing) return type(thing) == "userdata" and thing.isItem ~= nil and thing:isItem() end
local function isSelf(thing, player) return type(thing) == "userdata" and thing.isPlayer ~= nil and thing:isPlayer() and thing:getId() == player:getId() end

local fluids = Action()
fluids:onUse(function(player, item, fromPosition, target, toPosition)
	local fluid = item:getSubType()
	if isItem(target) then
		local targetType = ItemType(target:getId())
		if targetType:isFluidContainer() and target ~= item then
			local targetFluid = target:getSubType()
			if targetFluid == FLUID_NONE and fluid ~= FLUID_NONE then
				target:transform(target:getId(), fluid)
				item:transform(item:getId(), FLUID_NONE)
				return true
			elseif targetFluid ~= FLUID_NONE and fluid == FLUID_NONE then
				item:transform(item:getId(), targetFluid)
				target:transform(target:getId(), FLUID_NONE)
				return true
			end
		end
		local source = targetType:getFluidSource()
		if source and source ~= FLUID_NONE then
			item:transform(item:getId(), source)
			toPosition:sendMagicEffect(CONST_ME_LOSEENERGY)
			return true
		end
	elseif type(target) == "userdata" and target.getGround ~= nil then
		-- Usado no chao (agua rasa etc.): o chao pode ser fonte de liquido.
		local ground = target:getGround()
		local source = ground and ItemType(ground:getId()):getFluidSource() or FLUID_NONE
		if source ~= FLUID_NONE then
			item:transform(item:getId(), source)
			return true
		end
	end

	if fluid == FLUID_NONE then
		player:sendTextMessage(MESSAGE_STATUS_SMALL, "It is empty.")
		return true
	end
	if isSelf(target, player) then
		if fluid == FLUID_BEER or fluid == FLUID_WINE or fluid == FLUID_MEAD or fluid == FLUID_RUM then
			player:addCondition(drunk)
		elseif fluid == FLUID_MANA then
			player:addMana(math.random(50, 150))
			fromPosition:sendMagicEffect(CONST_ME_MAGIC_BLUE)
		end
		player:say(fluidMessage[fluid] or "Gulp.", TALKTYPE_MONSTER_SAY)
		item:transform(item:getId(), FLUID_NONE)
		return true
	end
	local pos = toPosition
	if not pos or pos.x == CONTAINER_POSITION then pos = player:getPosition() end
	local splash = Game.createItem(2886, fluid, pos)
	if splash then splash:decay() end
	item:transform(item:getId(), FLUID_NONE)
	return true
end)
fluids:id(table.unpack(fluidContainers))
fluids:register()

-- Pao: trigo -> moinho -> farinha (+ agua) -> massa -> forno -> pao.
local millstones = { [1943] = true, [1944] = true, [1945] = true, [1946] = true }
local ovens = {}
for id = 2535, 2542 do ovens[id] = true end

local bread = Action()
bread:onUse(function(player, item, fromPosition, target, toPosition)
	local id = item:getId()
	local targetId = isItem(target) and target:getId() or 0
	if id == 3605 then -- feixe de trigo no moinho
		if not millstones[targetId] then
			player:sendTextMessage(MESSAGE_STATUS_SMALL, "Use the wheat on a millstone to make flour.")
			return true
		end
		item:remove(1)
		player:addItem(3603, 1)
		toPosition:sendMagicEffect(CONST_ME_POFF)
		player:sendTextMessage(MESSAGE_STATUS_SMALL, "You grind the wheat into flour.")
		return true
	elseif id == 3603 then -- farinha na agua
		if targetId ~= 0 and isFluidContainerId[targetId] and target:getSubType() == FLUID_WATER then
			item:remove(1)
			target:transform(targetId, FLUID_NONE)
			player:addItem(3604, 1)
			player:sendTextMessage(MESSAGE_STATUS_SMALL, "You mix the flour with water and make a lump of dough.")
			return true
		end
		player:sendTextMessage(MESSAGE_STATUS_SMALL, "Use the flour on a container with water to make dough.")
		return true
	elseif id == 3604 then -- massa no forno
		if not ovens[targetId] then
			player:sendTextMessage(MESSAGE_STATUS_SMALL, "Use the dough on an oven to bake bread.")
			return true
		end
		item:remove(1)
		player:addItem(3600, 1)
		toPosition:sendMagicEffect(CONST_ME_HITBYFIRE)
		player:sendTextMessage(MESSAGE_STATUS_SMALL, "You bake a fresh bread.")
		return true
	end
	return false
end)
bread:id(3603, 3604, 3605)
bread:register()
