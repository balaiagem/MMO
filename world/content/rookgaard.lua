local guide = Game.createNpcType("Island Guide")
guide:outfit({ lookType = 1, lookHead = 0, lookBody = 0, lookLegs = 0, lookFeet = 0 })
guide:health(150)
guide:maxHealth(150)
guide:walkInterval(0)
guide:walkSpeed(0)
guide:attackable(false)
guide:isIdle(false)
guide:eventType("say")
guide:onSay(function(player, messageType, message)
	local text = string.lower(message or "")
	if text:find("hi", 1, true) or text:find("hello", 1, true) or text:find("ola", 1, true) or text:find("olá", 1, true) then
		selfSay("Welcome to Rookgaard! Ask me about town, training, or the cave.", player)
	elseif text:find("town", 1, true) then
		selfSay("The square is in the heart of town. The inn is west, and the training hall is east.", player)
	elseif text:find("training", 1, true) then
		selfSay("Start with the rats in the southern fields. They are weak, but watch your health.", player)
	elseif text:find("cave", 1, true) then
		selfSay("The cave entrance is north of the square. Rats below are more dangerous.", player)
	elseif text:find("bye", 1, true) then
		selfSay("Safe travels!", player)
	end
end)
guide:eventType("appear")
guide:onAppear(function()
	return true
end)
guide:eventType("think")
guide:onThink(function()
	return true
end)

local islandStartup = GlobalEvent("RookgaardIslandStartup")
islandStartup:type("startup")
islandStartup:onStartup(function()
	Game.createNpc("Island Guide", Position(114, 111, 7), true, true, CONST_ME_NONE)
	return true
end)
islandStartup:register()
