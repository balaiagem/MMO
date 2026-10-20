-- Local QA GM commands. Every command is restricted to access-level groups.
local thresholds = { [1]=0, [2]=300, [3]=900, [4]=2700, [5]=6500 }
local Characters=dofile('data/lib/dnd_characters.lua').new(dofile('data/lib/dnd_character_data.lua'))
local function abilityMod(score) return math.floor((score-10)/2) end
local function maxDndHp(player, lv)
 local cls=player:getStorageValue(95001)
 local abilities={}
 for i,key in ipairs({'STR','DEX','CON','INT','WIS','CHA'}) do abilities[key]=math.max(1,player:getStorageValue(95019+i)) end
 local maximum=Characters.derive(cls,player:getStorageValue(95002)>0 and player:getStorageValue(95002) or 1,lv,abilities,{feat=player:getStorageValue(95008)==1 and 'tough' or nil,subclass=Characters.classes[cls].subclass}).hp
 return player:getStorageValue(95101)>=4 and math.max(1,math.floor(maximum/2)) or maximum
end
local function sendProgress(p)
    local lv=math.max(1,math.min(5,p:getStorageValue(95003)))
    p:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE,string.format('[5E] PROGRESS level=%d xp=%d next=%d',lv,math.max(0,p:getStorageValue(95004)),({[1]=300,[2]=900,[3]=2700,[4]=6500})[lv] or 0))
end
local function setDndLevel(player, lv)
	lv=math.max(1,math.min(5,lv))
	local formed=player:getStorageValue(95469)==1
	local old=formed and player:getStorageValue(95461)or player:getMaxHealth()
	player:setStorageValue(95003,lv)
	if DndSyncTibiaLevel then DndSyncTibiaLevel(player,lv) end
	local maxDice=player:getStorageValue(95060);local remainingDice=player:getStorageValue(95061)
	if maxDice<0 then maxDice=lv end;if remainingDice<0 then remainingDice=maxDice end
	if lv>maxDice then remainingDice=remainingDice+(lv-maxDice) end;remainingDice=math.min(lv,remainingDice)
	player:setStorageValue(95060,lv);player:setStorageValue(95061,remainingDice)
	local hp=maxDndHp(player,lv)
	if formed then
        player:setStorageValue(95461,hp);player:setStorageValue(95460,math.min(hp,player:getStorageValue(95460)+math.max(0,hp-old)))
    else player:setMaxHealth(hp);if hp>old then player:addHealth(hp-old)end end
	player:setStorageValue(95004,thresholds[lv]);player:setStorageValue(95005,lv==4 and 1 or 0)
	for slot=1,3 do
  local magic=Characters.classes[player:getStorageValue(95001)].levels[lv].magic
  local count=magic['spell_slots_level_'..slot] or 0
		player:setStorageValue(95029+slot,count);player:setStorageValue(95032+slot,count)
	end
	sendProgress(player)
	player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE,string.format('[5E] LEVEL level=%d',lv))
	player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE,string.format('[5E] SLOTS slots1=%d slots2=%d slots3=%d max1=%d max2=%d max3=%d selected=%d',
		math.max(0,player:getStorageValue(95030)),math.max(0,player:getStorageValue(95031)),math.max(0,player:getStorageValue(95032)),
		math.max(0,player:getStorageValue(95033)),math.max(0,player:getStorageValue(95034)),math.max(0,player:getStorageValue(95035)),
		math.max(1,math.min(3,player:getStorageValue(95036)))))
	player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE,string.format('[GM] Nivel D&D %d aplicado; XP %d; PV maximos %d.',lv,thresholds[lv],hp))
end
local action=TalkAction('/gm')
action:separator(' ')
action:onSay(function(player,words,param)
	if not player:getGroup():getAccess() then player:sendTextMessage(MESSAGE_STATUS_SMALL,'Comando exclusivo do personagem GM.');return false end
	local args={};for word in string.gmatch(param,'%S+') do args[#args+1]=word end
	local command=string.lower(args[1] or 'help')
	if command=='help' then
		player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE,'[GM] /gm help | heal | level 1-5 | xp TOTAL | spawn rat|snake|spider|wolf|bug|orc|troll | slots | reset | tp X Y Z. /dndprogress e /rest short N ou long')
	elseif command=='heal' then
		player:addHealth(player:getMaxHealth()-player:getHealth())
		for slot=1,3 do local key=95029+slot;player:setStorageValue(key,player:getStorageValue(95032+slot)) end
		player:setStorageValue(95061,math.max(1,player:getStorageValue(95060)))
		player:setMana(player:getMaxMana());player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE,'[GM] PV e espacos de magia restaurados.')
	elseif command=='level' then
		local lv=tonumber(args[2]);if not lv or lv<1 or lv>5 or lv~=math.floor(lv) then player:sendTextMessage(MESSAGE_STATUS_SMALL,'Uso: /gm level 1-5') else setDndLevel(player,lv) end
	elseif command=='xp' then
		local xp=tonumber(args[2]);if not xp or xp<0 or xp>100000 or xp~=math.floor(xp) then player:sendTextMessage(MESSAGE_STATUS_SMALL,'Uso: /gm xp TOTAL (0-100000)') else
			player:setStorageValue(95004,xp)
			local lv=1;for n=2,5 do if xp>=thresholds[n] then lv=n end end
			setDndLevel(player,lv);player:setStorageValue(95004,xp);sendProgress(player)
		end
	elseif command=='spawn' then
		local names={rat='Rat',snake='Snake',spider='Spider',wolf='Wolf',bug='Bug',orc='Orc',troll='Troll'}
		local name=names[string.lower(args[2] or '')]
		if not name then player:sendTextMessage(MESSAGE_STATUS_SMALL,'Uso: /gm spawn rat|snake|spider|wolf|bug|orc|troll') else
			local current=player:getPosition()
			local offsets={[0]={0,-1},[1]={1,0},[2]={0,1},[3]={-1,0},[4]={-1,1},[5]={1,1},[6]={-1,-1},[7]={1,-1}}
			local offset=offsets[player:getDirection()] or {0,1}
			local pos=Position(current.x+offset[1],current.y+offset[2],current.z)
			local monster=Game.createMonster(name,pos,true,true)
			player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE,monster and '[GM] '..name..' criado ao lado.' or '[GM] Sem espaco para criar criatura aqui.')
		end
	elseif command=='slots' then
		for slot=1,3 do local key=95029+slot;player:setStorageValue(key,player:getStorageValue(95032+slot)) end
		player:setMana(player:getMaxMana());player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE,'[GM] Espacos de magia recuperados.')
	elseif command=='reset' then
		for _,key in ipairs({95410,95420,95421,95430,95441,95442,95443,95450,95451,95480,95481,95490,95491,95492})do player:setStorageValue(key,0)end
		player:setStorageValue(95003,1);player:setStorageValue(95004,0);player:setStorageValue(95005,0);player:setStorageValue(95008,0);player:setStorageValue(95009,-1)
		for i=0,5 do local base=player:getStorageValue(95040+i);if base>0 then player:setStorageValue(95020+i,base) end end
		local baseAc=player:getStorageValue(95046);if baseAc>0 then player:setStorageValue(95010,baseAc) end
		setDndLevel(player,1);player:setStorageValue(95004,0)
		player:setStorageValue(95060,1);player:setStorageValue(95061,1)
		player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE,'[GM] Progresso 5e reiniciado; atributos de criacao restaurados quando disponiveis.')
	elseif command=='tp' then
		local x,y,z=tonumber(args[2]),tonumber(args[3]),tonumber(args[4])
		if not x or not y or not z or z<0 or z>15 then player:sendTextMessage(MESSAGE_STATUS_SMALL,'Uso: /gm tp X Y Z') else player:teleportTo(Position(x,y,z),true) end
	else player:sendTextMessage(MESSAGE_STATUS_SMALL,'Comando desconhecido. Use /gm help.') end
	return false
end)
action:register()
