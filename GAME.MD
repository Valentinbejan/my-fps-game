# BLOOD KEY
## Design Document – Vertical Slice
**PSX-styled Ultrakill × Resident Evil hybrid**

A silent, highly skilled hunter trapped in a gothic mansion that has become a thin place into hell. You fight with full Ultrakill movement and stylish FPS combat, but you live under Resident Evil-style resource and inventory pressure inside an interconnected, key-locked environment.

This document describes the **first playable vertical slice** (a small but complete loop of a few rooms) so the core fantasy can be proven before expanding.

---

### High Concept

You are a silent, highly skilled hunter (V1-like precision mixed with Leon-like competence). The mansion is rotting, foggy, and oppressive. Hallways feel tense and dangerous. When you enter a combat space the game explodes into high-speed, high-skill, blood-soaked spectacle: dashing, sliding, slamming, air dashes, wall kicks, instant weapon swaps, projectile parries, and style ranks.

You cannot carry everything. Inventory is a medium-sized grid. You will constantly decide what to keep, what to leave in a storage box, and when to craft. Ammo is limited. Blood heals you if you play aggressively and get close.

The look is **stylized low-poly PSX**: chunky models, dithered/low-res textures, vertex lighting, heavy fog, and CRT/scanline filters, but kept cleaner and more readable than authentic 1998 hardware so the fast movement stays fun.

Tone: Horror and tension in the halls. Over-the-top stylish violence in the fights.

---

### Art Direction (Stylized Low-Poly PSX)

- Low-poly models (player ~600–900 tris, enemies 400–800, environments modular and blocky).
- Textures 64×64 to 256×256, dithered, limited palettes, visible pixelation.
- Vertex lighting only + colored lights (deep reds, sickly greens, cold moonlight, hellish orange).
- Distance fog used both for atmosphere and to hide draw distance.
- Optional but recommended: mild affine warping, dithering shader, scanlines, slight chromatic aberration, 480p or 720p with CRT overlay.
- Blood is chunky red sprites + simple meshes. Lots of it.
- UI: bitmap fonts, simple 2D overlays that look like a late-90s pause menu. Inventory grid with rotatable item icons.
- No real-time shadows (or very cheap blob shadows). High contrast lighting.
- Overall feel: a lost 1998–1999 game that mixed Resident Evil atmosphere with fast action, but rendered a bit cleaner so movement remains readable.

The mansion should feel like the Spencer Mansion if it had been built over a hell rift: wood paneling, statues, grand stairs, libraries, and suddenly impossible geometry, blood, and demonic growths.

---

### Core Gameplay Loop (Vertical Slice)

1. Explore tense, foggy hallways and rooms.
2. Find keys, herbs, ammo, and weapons.
3. Manage a medium grid inventory (drop items or use storage boxes).
4. Craft health or ammo when you have a safe moment.
5. Enter a combat space → full Ultrakill movement + stylish shooting + parrying.
6. Blood-heal by getting close and aggressive (high risk, high reward).
7. Open new paths / shortcuts and backtrack (fast movement makes this fun).

The slice must already feel like the full game in miniature.

---

### Movement (Full Ultrakill)

- Fast ground movement.
- Dash (ground + air, short i-frames or damage reduction).
- Slide (chainable, good for closing distance or dodging).
- Jump + Slam (ground pound that damages and launches you).
- Air dashes.
- Wall kicks / wall jumps.
- Excellent air control and floaty-but-snappy feel.
- Instant weapon switching (no long animations).
- Punch that parries most projectiles (parry = style + damage + possible health).

Movement must feel *excellent* first. Everything else is built around it.

---

### Combat

**Starting loadout**
- Weak pistol (common/cheap ammo, low damage).
- Melee punch (parry tool).

**Findable in the slice**
- Shotgun (close-range powerhouse).
- SMG / Nailgun-style (fast fire, great for style).
- Explosive (grenade launcher or similar, very limited ammo).

**Enemies (keep simple for the slice)**
- Slow, tanky demons/zombies (ammo sponges if you play poorly).
- Fast swarmers.
- Projectile shooters (parry bait).
- One unique / mini-boss enemy in the main combat room.

**Style ranking**: D → C → B → A → S → SS → SSS. Variety, speed, no-damage, parries, and weapon swaps increase it. High rank feels satisfying (juice, extra blood, or just spectacle).

Blood healing: dealing damage up close or killing restores health. Aggressive play is rewarded but risky because ammo and inventory space are limited.

Combat rooms should have verticality, rails, and space to dash/slam/wall-kick.

---

### Inventory & Crafting (Medium Pressure)

- Grid inventory (example starting size: 4×5 or 5×4, enough for 2–3 weapons + ammo + a couple of keys/herbs).
- Items occupy 1–4 slots. Weapons take more space. You can rotate items.
- You cannot carry every weapon + max ammo + all keys + materials at once.
- Storage box in at least one “safe-ish” room (like RE item boxes). Items left in the box stay there.
- You can drop items on the ground (they persist).
- Crafting: herbs combine into health items of different strengths. Some materials combine into ammo. Crafting happens in the paused inventory screen.

The tension should come from “I want to take the shotgun *and* the SMG *and* extra ammo, but then I have no room for the key or herbs.”

---

### Level Design – Vertical Slice Layout

A small but interconnected section of the gothic hell-mansion. Goal: 6–10 rooms that already demonstrate keys, multiple paths, storage, combat spectacle, and backtracking.

Suggested rooms (greybox first):

- **Entrance Hall** (hub) – Grand, foggy, statues, grand staircase. Storage box here. One locked door that needs a key found later.
- **West Corridor** – Tense, narrow, some lurking enemies. Leads to a small item room.
- **Library / Study** – Puzzle or key item + some ammo/herbs. Possible second entrance (window or later shortcut).
- **Main Combat Hall** (the “arena”) – High ceiling, balcony, rails, destructible cover. This is where the game goes full Ultrakill. Mini-boss or dense enemy wave here.
- **East Wing / Servant Rooms** – Smaller rooms with pickups, one locked door, maybe a vent or window that becomes a shortcut.
- **Upper Landing / Balcony** – Overlooks the combat hall. Good for slamming and vertical play.
- **One extra locked room** that requires the key from the library. Contains a better weapon or important item.
- **One shortcut** that opens after you progress (unlocked door, destroyed wall, or ladder) so backtracking feels faster.

Multiple ways into at least two important rooms. Lighting and fog hide things and create atmosphere. Secrets (extra ammo or a herb) in slightly out-of-the-way spots.

The slice should take 15–30 minutes to complete on a first playthrough, but be replayable while testing movement and inventory.

---

### Prototype Content Checklist

**Must have in the first playable version:**
- Full Ultrakill movement (dash, slide, slam, air dash, wall kick).
- Pistol + punch (parry).
- Shotgun, SMG, and one explosive weapon.
- Medium grid inventory + storage box + drop items.
- At least two keys / locked doors.
- Basic crafting (herbs → health).
- 3–4 enemy types + one unique enemy.
- Style ranking.
- Blood healing.
- One small interconnected greybox map as described above.
- PSX-style shaders (fog, vertex lighting, dither, optional CRT).

**Nice to have (add if time):**
- A simple map or notes for lore.
- One extra shortcut.
- More juice (hitstop, screen shake, blood particles, style announcements).

---

### Technical Notes

- Engine: Unity (recommended) or Godot 4.
- First-person controller built or heavily modified for the movement listed above.
- Inventory as a 2D grid with drag-and-drop and rotation.
- Doors check inventory for required key.
- Everything data-driven (ScriptableObjects or equivalent) so adding a weapon, key, or enemy later is easy.
- Greybox the map with simple geometry first. Art and shaders come after the loop feels good.
- Keep the slice small. The goal is “this already feels like the game I want to make,” not a full campaign.
