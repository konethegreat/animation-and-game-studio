# BIN CITY: The Long Shift, expansion design

Date: 2026-11-02
Status: approved by owner instruction, implemented autonomously overnight
Worktree: `C:\Users\Konet\bin-city`, branch `bin-city`

## 1. Intent

The first build is a solid ten minute shift. This expansion turns it into a
forty five to sixty minute small game: a story told over five shifts in three
districts, with people in the streets, rooms to enter, a boss, a character who
visibly grows, and a city that looks like a picture book.

Pillars:

1. **A city worth saving.** Density, characters and small stories in every
   street. No empty squares.
2. **The mechanic is the fantasy.** Vacuum, carry, sort. Every rank adds a new
   way to use those verbs, not a new unrelated minigame.
3. **Readable spectacle.** Strong silhouettes, warm light, one accent per
   district, effects that support play and never hide litter.
4. **Always playable.** Cutscenes, loading cards and story never block for
   long, and everything skippable is skipped with one key.

The 40 MB web build ceiling is lifted for this work. Output stays local, free
and original.

## 2. Story

### 2.1 Setting and cast

**Marrow Bay** is a small harbour city built around a canal and a morning
market. Its civic emblem is the Dawn Turnip, a brass statue in the market
square. The Bureau of Clean Streets is underfunded and beloved.

- **You**, the rookie sweeper. Silent protagonist, named by rank only.
- **Nell Quill**, depot dispatcher. Dry, warm, talks through the radio and
  hands out shifts. She believes in the Bureau and in you.
- **Rook**, a rival sweeper on a chrome cart. Fast, vain, secretly decent. He
  takes shortcuts, gets stuck, and becomes your ally.
- **Director Sullage**, head of Sullage Haulage. The city's private waste
  contractor. He profits when the streets look dirty, because the city renews
  his contract every time the Bureau fails.
- **Odo**, the canal ferryman. Knows every bottle in Marrow Bay by name.
- **Pip**, an arcade kid who sees everything from the roof.
- **Miso**, a grey cat. Optional friend.
- **The Gulper**, a municipal waste engine that Sullage overclocked. Not evil.
  Hungry, confused and enormous.

### 2.2 The night tide

Sullage's crews dump waste into the city before dawn so that the Bureau looks
useless and the city renews his contract. The first build's market is the first
morning of that scheme. The player uncovers it over five shifts.

### 2.3 Beats

**Shift 1, Dawn Market, rank 1 to 2.** Nell's briefing: clean the market
before the nine o'clock bell, learn the vacuum, the carry and the sort. Rook
mocks the handcart. When the bell rings, Nell notices the rubbish came from
bins that were emptied the night before, not bins that were full all week.
Something is being dumped.

**Shift 2, Canal Quarter, rank 2 to 3.** The canal is choked. Odo says barges
unload at night. Rook is stuck on a bridge with a broken cart; help him and he
shares a Sullage Haulage manifest. The first drain grate is cleared. Rank 3.

**Shift 3, Canal Quarter after dark, rank 3 to 4.** Follow the manifest to the
lock gates. Sullage's foreman Grist dumps a load into the canal. Clear the
clogged drains and the lock before the quarter floods. Rook joins you. Rank 4.

**Shift 4, Neon Arcade, rank 4 to 5.** The arcade is buried. The Gulper is
awake and eating the street. Pip shows you the roof route. Clear the arcade
and reach the sorting plant. Rank 5.

**Shift 5, The Sorting Plant, boss.** The Gulper. Sullage tries to overclock it
by remote. You calm it by feeding it properly sorted waste. Ending: Sullage's
cart is towed away by a flock of rats, Nell promotes you, the statue is lit,
credits roll over the clean city.

### 2.4 Tone

Warm, dry, a little absurd. Nobody swears. No em dashes. Jokes are short and
mostly about bins, cats, gulls and municipal bureaucracy.

Sample lines:

- Nell: "Market's a mess, rookie. The bins were emptied last night and the
  street is still full. Make that make sense."
- Rook: "Nice cart. Does it come with a pension?"
- Odo: "That bottle has been down the canal twice. It knows the way home."
- Pip: "The big machine eats the street. I named it. You're welcome."
- Sullage: "Filth is a service. I provide it reliably."
- Gulper (subtitle only): a low, sad industrial groan.

## 3. World

### 3.1 District structure

Each district is a self contained playable area with:

- One or more **vacuum depots** (empty your hopper into the skip).
- One **sort station** (open the sorting modal).
- A **drop off** ring (finish the shift).
- **Interiors** with doors.
- A **crowd budget** of NPCs.
- A palette, a sky, a music bed and an ambience bed.
- A litter mix and a hazard set.
- A set of quest hooks and story beats.

Districts are built procedurally from code, as the current market is. No
imported models.

### 3.2 Dawn Market (existing, expanded)

Warm ochre and cream, bunting, canal edge, morning sun. Already dense. Add:

- More stalls and goods, a flower cart, a fish slab with gulls, a knife
  grinder's cart, stacked crates and awnings.
- Pigeon flocks, shoppers, children, two cats, a dog asleep under a stall.
- The depot interior (Bureau of Clean Streets), the bakery interior, and the
  canal boathouse interior.
- Steam vents, laundry lines, hanging lamps, paper lanterns.
- The nine o'clock bell as a world event: a visible clock and a bell strike.
- Side quests: bread run (bakery), lost cat (Miso).

### 3.3 Canal Quarter

Teal, stone, mist, wet cobbles. Narrow lanes around a wide canal, three
bridges, moored boats, stairways down to the water, washing lines, lamps
reflected in the water. New mechanics:

- **Canal litter** floats on the water and can be vacuumed from the bank.
- **Drain grates** slowly pull floating litter into the canal. Clearing grime
  from a grate stops the pull and releases a small burst of litter.
- **Slippery steps** near the water cause the existing slip, with a wider
  margin in rain.
- **Night shift**: the third visit happens after dark. Lamps, windows and
  reflections carry the light. Neon Arcade rain shader is reused at low
  intensity.

Set pieces: the lock gates, a cranky swing bridge, Odo's ferry, a bottle
return machine, a canal-side chippy with a queue.

### 3.4 Neon Arcade

Magenta and cyan over deep blue. A covered arcade street of cabinets and
stalls, a rooftop route reached by fire escape, puddles with neon
reflections, rain. New mechanics:

- **Rain** reduces traction slightly and adds splash particles.
- **Electric puddles** near broken signs cause a brief stun unless cleared of
  litter that is shorting them.
- **Night lighting**: emissive signs, window grids, lamp cones, wet
  reflections.
- **The sorting plant** as the boss arena, entered through a loading card.

Set pieces: the arcade cabinet wall, a rooftop pigeon coop, a giant neon
turnip sign, the plant's intake mouth.

### 3.5 Interiors

Each interior is a compact room built by an interior builder, with its own
palette, props, NPCs, ambience and exit door. Interiors are separate areas
swapped behind a loading card, not separate Godot scenes, so game state stays
in one place.

1. **Bureau Depot** (Dawn Market): Nell's counter, rank board, save point,
   upgrade board, radio. The hub between shifts.
2. **Bakery** (Dawn Market): ovens, flour sacks, a rat nest, the baker.
   Side quest.
3. **Boathouse** (Canal Quarter): Odo's bottles, charts, a stove, a cat.
4. **Arcade** (Neon Arcade): cabinet wall, a playable high score interaction,
   Pip's hideout.
5. **Sorting Plant** (Neon Arcade): boss arena.

### 3.6 Density rule

Every screen should contain at least three things that are not gameplay:
a character doing something, an animal, a sign, a plant, steam, laundry or a
piece of set dressing. This is a review criterion for each district.

## 4. Progression

### 4.1 Ranks

Five ranks, each with a visible body change, a stat change and an ability.
The rank title card and a two second flourish play on promotion.

| Rank | Title | Look | Carry | New ability |
| --- | --- | --- | --- | --- |
| 1 | Street Sweeper | straw cap, apron, broom, handcart | 1 | none |
| 2 | Bag Baron | teal coat, flat cap, scarf, satchel, tank | 3 | sprint and a wider vacuum |
| 3 | Scrap Knight | patchwork armour of signs and plates, magnet gauntlet, wheeled rig | 5 | **magnet pull**: pull metal litter within range |
| 4 | Recyclord | bottle cap crown, tarpaulin cape, turbine cart | 8 | **sort aura** and double jump |
| 5 | Cosmic Custodian | luminous suit, orbiting bins, comet broom, visor | 12 | **cleanse pulse**: radial clean and stun |

Rank 3 and above are built by adding parts to the existing rig, not by
swapping the whole character. Each rank keeps the silhouette readable from
the default camera distance.

Abilities:

- **Sprint**: hold Shift, stamina free, small FOV kick.
- **Magnet pull**: hold the interact key near metal litter to draw it in.
- **Sort aura**: correctly sorted litter adds a flow bonus and nearby
  collectable litter is tagged with its sort kind.
- **Double jump**: one extra midair jump, with a puff of dust.
- **Cleanse pulse**: a radial burst on a cooldown that collects light litter
  and stuns rats and boss junk.
- **Glide** (rank 5): hold jump while falling to slow the descent.

### 4.2 XP

XP comes from: litter collected (10 to 40 by weight), correct sorts (60),
vacuum bursts (20), quests (200 to 400), story beats (500), boss chute hits
(100). Thresholds: 0, 600, 1800, 3600, 6000. The HUD shows a rank progress
bar. XP and rank persist across shifts.

### 4.3 Shifts

A shift has: a briefing line, objectives, a cleanliness target, a drop off
condition, and a reward. Progress and flags are stored in GameState. The hub
depot lets you reselect unlocked shifts and replay them for score without
losing story progress.

## 5. Movement and camera

- Walk, sprint, jump, land, dash (rank 3+), double jump (rank 4+), glide
  (rank 5).
- **Coyote time** 0.12 s, **jump buffer** 0.14 s, variable jump height.
- Acceleration and deceleration tuned for weight; air control at 65 percent.
- **Dash**: 0.18 s burst on a 0.8 s cooldown, small afterimage.
- **Camera**: smoothed spring follow, look ahead in the movement direction,
  collision sphere, sprint FOV from 70 to 76, landing dip, shake bus honouring
  reduced motion.
- **Animation**: existing procedural walk, plus jump, land, dash, glide poses,
  rank-specific idle flourishes, and a carry load lean.
- **Traction**: rain and canal steps reduce grip for a short slip.

## 6. NPCs and dialogue

### 6.1 Crowd

A crowd manager per area keeps a budget of NPCs (Dawn 14, Canal 10, Neon 12,
interiors 2 to 4). NPCs are simple procedural characters with a palette
variation, a role, a schedule and a dialogue table. They are culled by
distance for animation updates, not hidden.

Archetypes:

- **Stall keeper**: stays near a stall, waves, sells, gives a line.
- **Shopper**: walks between stall points, pauses to look at goods.
- **Child**: runs in arcs, follows the player at a distance, asks questions.
- **Ferryman**: Canal, stands at the landing, gives the bottle quest.
- **Arcade kid**: Neon, plays a cabinet, gives hints.
- **Pigeon flock**: scatters from the player and from the vacuum.
- **Cat**: lounges, follows Miso, sits on warm surfaces.
- **Rat**: steals litter, flees, drops it when scared.
- **Dog**: asleep, wakes and follows at rank 4+.

### 6.2 Reactions

- Vacuum within 3 m: NPCs sidestep, hold hats, laugh.
- Cleanliness above 80 percent: keepers cheer, children clap, lamps warm.
- Rank up: nearby NPCs clap and a confetti puff appears.
- Boss arena: NPCs absent, sound bed changes.

### 6.3 Dialogue

A dialogue panel at the bottom of the screen: speaker name, typewriter text,
one to three choices, advance with E or click. Gameplay pauses during
dialogue but the world keeps breathing (animation only). Dialogue is
data driven per speaker and story flag. Quest choices are explicit.

All dialogue is subtitled, so the game is fully playable muted.

## 7. Loading and transitions

A transition covers: player enters a door, shift changes, boss intro, ending.

The screen is a stylised card in the district palette: a sweeping broom
silhouette wipe, the area name, one line of flavour, and a tip. Minimum
0.8 s so it reads, skippable after 0.3 s. The world swap happens behind the
card, then the card lifts.

State kept across transitions: player rank, hopper, carried stack, XP, quests,
story flags, camera yaw. Gameplay state that should reset per area (rats,
litter layout, crowd) is rebuilt by the area.

## 8. Boss: The Gulper

Arena: the sorting plant floor, three sorting chutes on the Gulper's flank,
a central conveyor, steam, warning lamps.

### Phase 1, HUNGRY

- The Gulper patrols slowly along a rail. Its intake pulls loose litter and
  the player toward it.
- It coughs out clumps of mixed junk every few seconds.
- Three chutes open in sequence, each labelled paper, metal, glass.
- Player vacuums junk, sorts it, throws each item into the matching chute.
  A correct hit deals damage. A wrong hit feeds it and spawns a hazard.
- Health 100. Chute hits deal 12. Every third hit triggers a stomp shockwave.

### Phase 2, OVERCLOCKED

- Sullage's voice over the plant radio overclocks the machine.
- Faster patrol, junk volleys, two chutes open at once, steam vents.
- The arena floor floods with the night tide, raising the slip risk.
- Health 100. Same damage loop, tighter windows, adds "grime patches" that
  must be vacuumed before chutes will accept litter.

### Phase 3, CALMING

- The machine slows and groans. Its core opens.
- The player empties a full hopper into the core through a final chute.
- A short cutscene: the Gulper powers down, Sullage is towed away by rats,
  Nell promotes you, the city lights up.

Boss UI: name and health bar, phase pips, a prompt strip for the open chute,
and a warning flash for the suction and stomp. Reduced motion keeps the
telegraphs but removes shake.

## 9. Cutscenes

A timeline player advances steps in sequence: wait, camera move, dialogue,
subtitle, flag, spawn, music, shake. Cutscenes pause gameplay, can be skipped
with Escape or the interact key, and always leave the game in a playable
state.

Cutscenes:

1. **Cold open** (title, 20 s): dawn over the dirty market, Nell's radio
   call, the camera settles on the player. Skippable from the title card.
2. **Rank ups** (2 s each): camera orbit, gear parts fly in, title card.
3. **District transitions** (6 s each): a pan over the new district with one
   line of narration.
4. **Night fall** (8 s): the market darkens, lamps come on, the night tide
   arrives.
5. **Boss intro** (12 s): the plant wakes, the Gulper rises, Sullage speaks.
6. **Ending** (30 s): the Gulper sleeps, rats tow Sullage, Nell promotes you,
   the statue lights, credits.

## 10. Visual direction

### 10.1 Art direction

A painted diorama: chunky proportions, flat colour faces with soft gradients,
strong silhouettes, warm key light, cool fill, one accent per district.
Dawn Market is ochre and coral, Canal Quarter is teal and stone, Neon Arcade
is deep blue with magenta and cyan. Interiors use the district palette plus
one warm practical light.

Characters get a subtle dark outline and a toon ramp. Props use cleaner
materials with slight colour variation. The player is always the brightest
warm shape in frame.

### 10.2 Rendering and post

- **Environment**: gradient sky shader, sun key light, cool ambient fill,
  distance fog, filmic tonemap, debanding.
- **Post layer**: a single full screen shader over the 3D view with a warm
  highlight and teal shadow grade, a soft vignette, fine grain and a light
  paper texture. Strength scales with the quality setting. Glow is enabled
  where the Compatibility renderer supports it, with sprite halos as the
  fallback for lamps and neon.
- **Shadows**: one directional shadow plus a small number of lamp shadows.
  Blob shadows under NPCs and props too far from the light.
- **Particles**: dust motes in sunbeams, steam vents, canal mist, rain,
  splash rings, leaf drift, confetti on rank up, boss steam. CPU particles
  for the web build, GPU particles only where measured safe.
- **Shaders**: toon ramp for characters, inverted hull outline, water with
  foam and ripples, neon emission flicker, rain streaks, cloth sway for
  bunting and laundry, a wet ground sheen shader for the arcade.
- **Quality setting**: Low, Standard, High. Low disables post grade, outlines
  and most particles; Standard is the default web preset; High adds extra
  light and particles.

Exact effect support is confirmed by the renderer research note before the
post layer is wired. Unsupported effects fall back to the emissive and sprite
techniques above. No visual effect may reduce litter contrast.

### 10.3 UI art direction

The existing cream and ink UI stays. Add a paper grain, a thin ink border, a
district accent per screen, a loading card, a dialogue box with a speaker
rule, a quest log, a boss bar, a rank progress bar and a credits card. All UI
motion respects reduced motion.

## 11. Audio

- **Music**: one loop per district (Dawn Market keeps its existing cue),
  Canal Quarter waltz, Neon Arcade synth, a boss theme with three intensity
  layers, and an ending cue. Generated at load from oscillators and noise.
- **Layers**: a calm layer and a busy layer crossfade with combat or
  cleanliness.
- **Ambience**: market murmur, gulls, water lap, arcade hum, rain, plant
  machinery, room tone per interior.
- **SFX**: jump, land, dash, magnet, pulse, door, loading whoosh, dialogue
  blips per speaker, chute correct, chute wrong, boss roar, stomp, reveal
  sting, rank fanfare (existing), unlock, cat, pigeon, rat, bell.
- **Mix**: music at minus 8 dB, ambience at minus 14, SFX at minus 4, boss
  theme ducking the ambience. Mute persists.

## 12. UX and accessibility

- Keyboard and mouse, gamepad and touch all reachable: move, look, jump,
  sprint, vacuum, interact, sort, pause, skip.
- Touch gets jump and interact buttons plus the existing stick and look pad.
- Reduced motion setting: removes camera shake, grain flicker, confetti and
  wipe motion, keeps all information.
- Subtitles on for all speech. Dialogue can be advanced with one key.
- Pause shows objectives, controls and a resume, restart and settings menu.
- Settings: mute, reduced motion, quality, reset save, quit to title.
- Save is automatic after shifts, rank ups and quest steps. Continue appears
  on the title card when a save exists.

## 13. Technical architecture

```
projects/011-bin-city/
├─ project.godot            autoloads: GameState, Sound, Dialogue
├─ main.tscn                root with Game
├─ scripts/
│  ├─ game.gd               orchestrator: phases, input, area loading, boss
│  ├─ game_state.gd         autoload, save and load, XP, flags, quests
│  ├─ dialogue.gd           autoload, dialogue tree runner and signals
│  ├─ data.gd               rank, district, quest and dialogue tables
│  ├─ district.gd           base area: ground, bounds, density helpers
│  ├─ dawn_market.gd        existing world, moved and expanded
│  ├─ canal_quarter.gd      new district
│  ├─ neon_arcade.gd        new district
│  ├─ interior.gd           base interior builder
│  ├─ interiors.gd          depot, bakery, boathouse, arcade, plant
│  ├─ crowd.gd              NPC budget and schedules
│  ├─ npc.gd                one procedural character
│  ├─ boss.gd               Gulper state machine and arena
│  ├─ cutscene.gd           timeline player
│  ├─ transition.gd         loading cards and wipes
│  ├─ postfx.gd             post layer host and quality
│  ├─ player.gd             movement, abilities and rank rig
│  ├─ litter.gd, pile.gd, rat.gd, kit.gd, sound.gd, ui.gd
│  └─ shaders/              water, toon, outline, neon, rain, post, sky
└─ tests/                   headless smoke and logic tests
```

`game.gd` stays the only place that knows about phases. Districts expose
`set_clean`, `is_free`, `random_walkable`, `stations`, `interiors`, `spawn`,
`ambience` and `music`. Interiors expose the same area API with a smaller
footprint.

## 14. Performance and budget

- Target 60 fps at 1280x720 on desktop, 30 fps on low end web, with a frame
  time check in the debug overlay.
- Draw calls: keep the market under 500, new districts under 400. Merge static
  meshes where possible, share materials through the kit cache.
- Particles: at most 300 live CPU particles per area, 150 on low.
- Lights: 1 directional plus 4 omni shadowless for most areas, 1 omni shadow
  in the boss arena.
- NPCs: 14 maximum in the market, animation updates throttled beyond 18 m.
- Textures: 256 px procedural at most, shared.
- Build size: no new hard ceiling, but keep the web build lean enough to load
  in under 30 seconds on a normal connection.

## 15. Testing and definition of done

1. `studio validate` passes for all projects.
2. `pytest studio/tests` passes, including new headless tests for rank
   thresholds, save and load, dialogue flow, quest flags, boss damage and
   district transitions.
3. `studio build 011-bin-city --target web` succeeds and the game boots in a
   real browser.
4. Every district and every interior has been entered and played in the
   browser; the boss has been beaten; the ending has been seen.
5. A still from each district reads clearly and was viewed.
6. Reduced motion and mute verified.
7. Gamepad and touch controls verified as far as hardware allows; a note is
   left for anything untested.
8. `studio verify 011-bin-city` passes.
9. Small conventional commits on the `bin-city` branch. Merge and publish
   only after the film session releases main.
