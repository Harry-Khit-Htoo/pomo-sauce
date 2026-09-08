# Pomo Sauce — Mascot Visual Style Guide

The brief for anyone producing final art or animation for the mascot: an
illustrator, a Rive author, or an AI image tool generating individual poses.

The two supplied reference images are the anchor. **Attach them to any ticket
or prompt that produces new poses** — exact linework, eye shape and frame
counts should come from the art, not from this text.

Current implementation: [`lib/mascot/tomato_mascot.dart`](../lib/mascot/tomato_mascot.dart),
a `CustomPainter` built to this guide. Run

```bash
flutter test --update-goldens test/mascot_gallery_test.dart
```

to regenerate [`test/goldens/mascot_poses.png`](../test/goldens/mascot_poses.png) —
a 3×3 sheet of every pose for review without launching the app.

---

## 1. Base model — identical in every mood

| Element | Spec |
|---|---|
| **Render style** | Soft 3D "clay"/glossy toy render. Not flat vector, not photorealistic. Squishy. |
| **Body** | Near-spherical, very slightly flattened top to bottom. **Solid tomato-red in every pose.** |
| **Gloss** | One subtle specular highlight on the **upper right**, soft-edged. |
| **Ground** | A single soft blurred oval shadow underneath. No other ground treatment. |
| **Stem** | One thick, slightly curved green stem, centre top. |
| **Calyx** | 5–6 rounded glossy leaves fanned around the stem base. Each has a visible centre vein and its own small highlight. |
| **Cheeks** | Two soft oval blush marks, present in **every** expression. Position and width shift with the pose. |
| **Eyes** | Large rounded glossy dark-brown irises. Sclera shows only as a **thin rim** except where the pose opens the eye wide. One bright white specular dot near the **upper left** of each pupil, plus a smaller secondary. |
| **Linework** | Brows and mouth are clean, slightly thick **dark maroon/brown** strokes — never pure black. Soft hand-drawn arcs, not geometric shapes. |
| **Background** | Plain white / transparent. Export transparent PNG or vector for Rive/Lottie. |

### Palette

Everything lives in red body / green leaves / dark-maroon linework.
**Yellow is the only other colour in the system** and is used sparingly, for
the sparkle dashes and the alert mark only.

| Token | Value | Use |
|---|---|---|
| `tomatoTop` / `tomatoBottom` | `#F0543E` → `#CB2F28` | Body, default |
| `tomatoTopBright` / `…Bottom` | `#FF6A4F` → `#E23A2C` | Body, `happy` and `celebrating` |
| `tomatoTopDull` / `…Bottom` | `#E2685A` → `#BE3A31` | Body, `angry` and `sad` — a whisper, not a different fruit |
| `leaf` / `leafShade` | `#56B04A` / `#3A8A34` | Calyx, stem, leaf veins |
| `ink` | `#4A1A14` | All linework and the anger mark |
| `blush` | `#FF8278` | Cheeks (shifts toward `#FF9A5C` when annoyed) |
| `tongue` | `#FF7E86` | Inner mouth |
| `sparkle` | `#FFC53D` | Sparkle dashes and the alert mark — **the only yellow** |

---

## 2. Anchor poses (from the reference images)

Every other mood is a variation of this same rig — never a new style.

### Happy / Content — *reference image 1, left*
Two simple upward-curved brow arcs. Eyes fully round and open with the
highlight dot. Small open smile: a curved mouth with a tiny dark opening, no
teeth. Both cheeks blushed evenly.
→ `MascotMood.happy` (animated, with a bounce) and `MascotMood.idle`
(the same face at rest).

### Playful / Wink — *reference image 1, middle*
One brow raised higher than the other. Left eye open, right eye closed in a
curved wink line. Closed-mouth smile — a single soft curve, no opening.
→ `MascotMood.neutral`. The wink **lands once per loop** rather than being
held, so a 25-minute focus session does not stare at you mid-wink.

### Excited / Cheering — *reference image 1, right*
Both eyes closed in cheerful upward crescents (`^ ^`). Wide open mouth showing
a rounded dark opening with a pink inner shade. Three small yellow dashes
beside the head.
→ `MascotMood.celebrating`, and the face of `MascotMood.welcoming`.

### Angry — *reference image 2*
Sharp, low, angled brow strokes pressing down over the eyes, inner corners
lower. Eyes narrowed, irises still carrying the highlight dot. Small closed
frown. Two jagged anger marks floating beside the **upper right** of the head,
in the same dark maroon as the face lines. Blush present but pushed lower and
wider and shifted **warmer/orange**, so it reads *annoyed* rather than unwell.
→ `MascotMood.angry`.

> The angry pose must motivate, never punish. In the app it is only ever shown
> alongside a supportive line ("Let's get back on track!"), and only fires for
> a habit genuinely missed — never for one the user simply has not reached yet
> today. See the mood rules in `lib/mascot/mood_selector.dart`.

---

## 3. Additional poses (not in the references)

Brief these as edits to the base model: change **only** brows, eyes, mouth and
the floating mark, so they drop into the same rig.

### Sad / deflated — `MascotMood.sad`
Brows angled **up-and-in** at the inner corners — the exact mirror of angry.
Eyes slightly smaller. Whole silhouette slumped and tilted. Simple small frown.
No anger marks. One small sweat drop beside the head. Gentle and sympathetic,
not distressed.

### Alert / reminder — `MascotMood.alert`
Happy/Content eyes. Brows raised higher and **straighter** — attentive, not
worried. Mouth a small flat neutral curve rather than an open smile. A small
yellow `!` floating beside the head, in the sparkle accent colour.

### Welcome / usher — `MascotMood.welcoming`
The Cheering face, paired with a small wave. In the current rig the
**upper-right calyx leaf waves side to side**; if a future rig grows an arm or
nub, move the wave there. A bounce alone is acceptable if the rig cannot wave.

### Sleepy — `MascotMood.sleepy`
Not in the references. Eyes closed in the same crescents as Cheering, small
content smile, slow breathing bob. Used during breaks.

---

## 4. Handoff notes

### If generating poses with an AI image tool
Always include **both anchor images** as reference, and state explicitly:

> Same character, same render style, same body, stem and leaves — change only
> the facial expression.

Model drift between poses is the main risk; a sheet that is 80% consistent
looks worse than one drawn plainly. Generate the whole set in one session and
review them side by side before accepting any of them.

### If building the Rive rig
Build **one** skeletal/mesh rig for the body + stem + leaves, then drive
brows, eyes, mouth and the floating mark as separate swappable layers. Every
mood shares the base mesh, which keeps the file small and keeps the poses
perfectly on-model.

Wire the state machine input to `MascotMood.riveInput`, which is already the
enum name — `idle`, `neutral`, `alert`, `happy`, `celebrating`, `angry`,
`sad`, `welcoming`, `sleepy`. If that mapping holds, swapping the painter for
a Rive file touches exactly one widget (`TomatoMascot`) and no app logic.

### The current Dart rig
The painter already follows this separation. `_Motion` is the pose table: one
record of interpolated numbers per mood (brow angle, weight, arc, asymmetry;
eye openness and wink; mouth open/curve/tongue; blush drop, width and warmth;
plus which floating mark). Moods **cross-fade over 420 ms** rather than
snapping, and the whole thing runs off a single `AnimationController`, so it
is cheap enough to leave on a focus screen for fifty minutes.

Adding a mood means adding an enum value and one `_Motion` entry — no new
drawing code, and nothing else in the app changes.

### Keeping the launcher icon on-model
The launcher icon, splash and feature graphic are **not** drawn from this
model any more: they are composited from the render at
`assets/branding/source/mascot_render.jpg`, which is the same character with
proper 3D shading. `draw_tomato()` in `tool/generate_assets.py` stays as the
vector reference the in-app `CustomPainter` is written against — the two must
still agree on proportion, palette and expression, so that the mascot on the
focus screen reads as the same character as the icon on the home screen.

If the base model changes here, update `draw_tomato()`, re-render the source
art to match, and re-run:

```bash
python tool/generate_assets.py
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```
