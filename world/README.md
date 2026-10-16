# World status

The upstream server checkout contains `data/world/world.otbm` and spawn/house files. Its content provenance has not been established, so it is not designated as the project's distributable adventure zone.

`rookgaard.json` defines the hand-built beginner island used by the local server. It is an original approximation, not an official Rookgaard map. The converter builds two walkable floors, the town, a cave entrance, and the rat spawns in `generated/`; `tools/setup-local.py` copies those files into the local server runtime.

When the installed Tibia asset package is available, `tools/build-content.py` imports its official environment and outfit sprites into the local 8.60 item IDs. It leaves the installed game files unchanged. TFS reserves item ID 105 for a poison field, so the authored earth path uses ID 110. Without installed assets, the converter falls back to the original project atlas.

The local island is still small: two floors, eight environment types, one guide, and rat spawns. It is a playable Rookgaard-inspired prototype, not a copy of CipSoft's full Rookgaard map. Imported sprite data is local and excluded from source control.
