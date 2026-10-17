-- Native item IDs: upper openings descend, wooden ladder ascends.
local access=Action()
access:onUse(function(player,item,fromPosition)
    if fromPosition.x==65535 then return false end
    local upwards=item:getId()==1948
    local z=fromPosition.z+(upwards and -1 or 1)
    if z<0 or z>15 then player:sendCancelMessage('A passagem esta bloqueada.');return true end
    -- Use the native Tile query. Imported compatibility helpers called an
    -- unavailable Tile:isWalkable(), aborting both ladders and sewer grates.
    local offsets=upwards and {{0,1},{0,0},{-1,0},{1,0},{0,-1},{-1,1},{1,1}} or {{0,0},{0,1},{-1,0},{1,0},{0,-1}}
    for _,offset in ipairs(offsets) do
        local destination=Position(fromPosition.x+offset[1],fromPosition.y+offset[2],z)
        local tile=Tile(destination)
        if tile and tile:getGround() and (not upwards or not tile:hasFlag(TILESTATE_FLOORCHANGE)) and tile:queryAdd(player)==RETURNVALUE_NOERROR then
            if tile:hasFlag(TILESTATE_PROTECTIONZONE) and player:isPzLocked() then
                player:sendCancelMessage(RETURNVALUE_PLAYERISPZLOCKED);return true
            end
            player:teleportTo(destination,false)
            return true
        end
    end
    player:sendCancelMessage('A passagem esta bloqueada.')
    return true
end)
access:id(435,433,482,483,1948)
access:register()
