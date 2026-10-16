# Rookgaard: verification of supplied source

Target: classic Tibia 8.60 presentation from the master development plan.

The supplied tibia-map-data-main.zip is a TibiaMaps minimap dataset. Its own
README specifies PNG map colors, PNG pathfinding data and JSON markers.
It contains 16 base floor map PNGs and no OTBM server map. The temple marker is
32097,32219,7; a Hyacinth marker is 32139,32176,7. The archive does not establish
that its current minimap geometry represents version 8.60.

A minimap pixel is not an ordered stack of Tibia item IDs. It does not specify
wall variants, furniture, containers, movable items, scripts, quest flags,
NPC dialogue/trade, or authoritative monster spawn definitions. No exact
conversion to a playable world can recover these missing data.

The bundled server/data/world/world.otbm has tile-area origins at x=512..1280,
y=768..1280, not the supplied Rookgaard coordinates. Candidate NPC Lua scripts
exist in server/data/npc, listed in world/rookgaard-source-audit.json. Their
version, dependencies and fidelity must be verified before deployment.

Required for an exact import: a compatible Rookgaard/world OTBM, matching items
OTB/XML, spawn/house XML files and NPC/monster/quest scripts for the chosen
version. The supplied minimap remains a reference and verification input.
The live game/map was not replaced with a fabricated minimap-derived world.
