# Local account and character management

Open `http://localhost:8080/otclient.html`, start the client and log in normally.
The local account selector shows native creature portraits, race, current D&D
class/level and world. Create and Remove open native Tibia-style modal windows.
Creation keeps the existing server-validated attributes, skills and Expertise,
and adds an outfit preview with the 133-color palette for head/body/legs/feet.

Removal requires the exact, case-sensitive name and valid account credentials.
The API verifies ownership and rejects an online character. It soft-deletes the
record using the native `players.deletion` flag; retained profiles/storage are
not destroyed by the endpoint. Login/listing exclude deleted characters, and
only active characters count against the 12-character account limit.

The HTTP API remains same-origin and loopback-only. Credentials are sent in
POST bodies, never URLs. Local creation UI data uses the same public catalogue
and authoritative preview as the browser form. Existing character IDs and
progress are preserved. The launcher now opens the game login page by default.

Browser HTTP requests are started on the main runtime thread. Starting an XHR
from the game's continuously running pthread prevented its completion callback
from running; follow-up catalogue/preview requests used to remain pending.
Lua callbacks still run through the game dispatcher. Normal OTC asset paths
(`data/things/860/`) and strict asset-manifest defaults remain unchanged.

## Selection, access and rest

- Selecting a target establishes initiative without native fist/weapon auto-hit
  effects. Floating dice remain for attack/spell resolution, not initiative rows.
- Space selects the nearest living monster on the same floor. It does not spend
  an action, toggle off that same target, select an NPC or intercept text entry.
- Use on sewer grates/ladder openings descends; wooden ladders ascend onto a
  valid landing. Native tile admission/PZ checks reject blocked destinations.
  Upper floor-change tiles are skipped to prevent immediate downward loops.
- Long rest is allowed in the temple protection zone and near Cipfried, or
  within three tiles of Amber on her floor. Active combat still prevents rest.
  The server updates the inventory's long-rest button as the player moves.

## Validation

- `python -m unittest tests.test_character_service tests.test_creation`
- `python tools/check-character-service.py`: live HTTP/DB test with two temporary
  accounts, full capacity, colors, exact-name confirmation, online rejection,
  soft deletion and released capacity. Cleans up its own generated accounts.
- `python tools/prepare-character-manager-qa.py` then
  `node tools/check-character-manager.cjs`: private WASM fixture, native list,
  portraits, creation preview and wrong-name confirmation. No character writes.
- `python tools/test-navigation.py`: Lua 5.1/5.5 access/rest/Space regressions.
- Existing combat-adapter regressions and native server CTest suite pass.
