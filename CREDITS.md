# Credits and provenance

## Project

BLOOD KEY concept and design: the project owner's `GAME.MD`.

Implementation, mansion layout, UI and synthesized sound effects: created for this demo using Godot and Blender. Since the asset pass of 29 September 2026, the props, furniture, doors, windows, stairs, enemies, pickups, weapons, textures and music all come from the downloaded library; the full per-file list is in `ASSET_REGISTER.md`.

## Supplied assets used

The following assets were already provided in this workspace. Their original folders have been preserved.

- First-person arm mesh, texture and animations: `assets-from-online/arms_rig.glb` (PSX First Person Arms pack). The demo uses the finger-gun idle and grab poses with a grip correction, and the supplied left jab animation.
- M1911: `assets-from-online/PSXMiscGuns/1911/1911.obj` and `1911_Texture.png`.
- Shotgun: `PSXShotgunPack[FIXED]/Files/pumpActionShotgun/PumpActionShotgunShort.obj` (short pistol-grip pump, so it sits in one hand) and `Textures/PAShotgunText.png`.
- Environment textures: supplied FoxTex RE-Named collection; selected wood, herringbone, stone, marble, metal and concrete images. Exact source mapping is recorded in `validation/texture_sources.json`.

Author and license documents for these supplied model and texture packs were not present in the inspected folders; attribution above records the available provenance without asserting a license.

## Shader references

The Godot 4 material and post-process shaders adapt the techniques in the supplied Godot PSX Starter Kit (vertex snapping, vertex lighting and ordered color dithering). The starter kit credits MenacingMecha and Lucas Angelo / Ahopness, with further shader references in its source files.

Its supplied MIT notice is retained at `fps-game/shaders/THIRD_PARTY_LICENSE.txt`.

## Engine and fonts

Godot Engine: MIT-licensed; its license text and third-party notices accompany the Windows build. Blender was used to author assets and is not included in the build.

The UI uses system fonts (Consolas/Courier New and Georgia/Times New Roman) with engine fallback. No Windows font files are redistributed.

## Added for the GAME.MD slice (29 September 2026)

Converted with Blender (transform, pivot and scale only; original UVs and textures kept) and exported to `fps-game/assets/models/`:

- SMG: `doctor-sci3nce/PSXMP5[FIXED]/MP5.obj` + `Textures/MP5Texture.jpg` (stockless body, magazine and trigger) → `smg.glb`. Doctor_sci3nce, license status "Doctor-conflict" in `ASSET_CATALOG.md`.
- Flare gun and flare round: `doctor-sci3nce/PSXMiscGuns/FlareGun/FlareGun.obj` + `Flaregun_Text_240.png` → `flaregun.glb`, `flare_round.glb`. Doctor_sci3nce, "Doctor-conflict".
- Ammo boxes: `doctor-sci3nce/PSXAmmoBoxes` 9mm and 12g (red and green) → `ammo_9mm.glb`, `ammo_shells.glb`, `ammo_flares.glb`. Doctor_sci3nce, "Doctor-conflict".
- Swarmer enemy: creature `W3` from `elbolilloduro/Paquete de modelos low poly estilo psx/Criaturas1/Criaturas.fbx` (posed mesh, texture reduced to 256 px) → `swarmer.glb`. Elbolilloduro, CC0 models.
- Black powder sack: Classic64 `Food/food_baking_flour.blend` (darkened) → `powder.glb`. Craig Snedeker, CC0.
- Lore note: Classic64 `Papers/papers_log_1.blend` → `note.glb`. Craig Snedeker, CC0.

Copied unchanged into `fps-game/assets/third_party/`:

- Daniel Jurys, PSX Derelict Furniture (CC0): chair, couch, mattress, shelf, vase.
- valsekamerplant, PSX Going Medieval (CC0, textures credited to KenneyNL): barrel, barrel_open, crate.

The Doctor_sci3nce license question recorded in `ASSET_CATALOG.md` is unresolved and applies to the pistol, shotgun and the new weapon/ammo models alike. Confirm the purchase/licence terms before any commercial release.

## Required attributions (asset pass, 29 September 2026)

- **3D Model: McPato** — Haunted Parish (statue, altar, candles, crest medallion, portraits, gothic door and window, cross, amphora, ritual disc, dead tree) and House Interior (chandelier, bookcase, clock, mirror frame, chairs, tables, lamps, coat rack, dresser, wardrobe, cabinet, laundry basket, broom, radio, vases, palm). CC BY 4.0.
- **Music: Crow Shade (@CrowSilencer)** — "The Veil of Night", "Something's wrong" and "Midnight Dreams" from *Mind's Eye*. Creative Commons Attribution.
- **Doctor_sci3nce** — pistol, shotgun, SMG, flare gun, ammo boxes, healing items, hand tools, rifles and revolver props. The catalogue's licence conflict for this creator is unresolved; confirm terms before commercial release.
- **Elbolilloduro** — enemy characters (bloody servants, rotting brute, ghoul caster, antlered swarmer and Housekeeper), village interior furniture, Abandoned House furniture and banister, Halloween props. CC0 models (some upstream textures from Textures.com and others; see catalogue notes).
- **valsekamerplant** — Going Medieval doors, windows, stairs, timber posts, tables, barrels, crates, sacks, vases and vines (textures credited to KenneyNL); Office bookcases, desks, armchairs, couch, lamp, clock and papers; house plants; wall columns and fence. CC0.
- **Daniel Jurys** — derelict chair, couch, mattress, shelf and vase. CC0.
- **Kkryy** — metal locker, clock, bucket, scythe, shovel, crowbar, gas mask, padlock, bottles, bracket fungus, log and stump. CC0.
- **MCSTEEG / Games by McSteeg** — farm tools and trash/debris pieces (product licence permits game use; no redistribution of the raw assets).
- **Nicowlas** — kitchen props (custom licence; no redistribution of the raw assets).
- **Retro Assets Library** — medical props and chainsaw (custom licence; no standalone redistribution).
- **Craig Snedeker** — Classic64 flour sack (black powder) and log paper (notes). CC0.
- **Foxhead / foxh3ad** — FoxTex textures on every wall, floor, ceiling, carpet and banner. CC0.
- **Drillimpact** — first-person arms. CC0.
