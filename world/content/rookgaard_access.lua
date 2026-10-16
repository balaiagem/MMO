-- Native item IDs: upper openings descend, wooden ladder ascends.
local access=Action()
access:onUse(function(player,item,fromPosition)
    if fromPosition.x==65535 then return false end
    local destination=Position(fromPosition.x,fromPosition.y,fromPosition.z)
    if item:getId()==1948 then
        destination:moveUpstairs()
    else
        destination.z=destination.z+1
    end
    local tile=Tile(destination)
    if not tile or not tile:getGround() or not tile:isWalkable() then
        player:sendCancelMessage('A passagem esta bloqueada.');return true
    end
    if tile:hasFlag(TILESTATE_PROTECTIONZONE) and player:isPzLocked() then
        player:sendCancelMessage(RETURNVALUE_PLAYERISPZLOCKED);return true
    end
    player:teleportTo(destination,false)
    return true
end)
access:id(435,433,482,483,1948)
access:register()
