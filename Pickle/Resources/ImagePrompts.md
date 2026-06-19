# PICKLE image generation prompts (ChatGPT image gen)

Generate each image, then drop it into the asset catalog under the asset name shown.
`TreatedImage` loads it by name and applies the in app duotone treatment automatically,
so you do not need to edit any code. If an asset is missing, the app falls back to the
dark gradient placeholder, so you can add images one at a time.

## Shared style (paste this at the top of every prompt)

> Monochrome, near black and white editorial photograph in the style of a premium fitness
> and food brand. Deep true blacks, controlled highlights, high contrast, cinematic single
> source lighting, shot on medium format with a shallow depth of field. Desaturated, almost
> no color. Moody, calm, expensive, understated. Lots of empty negative space. No text, no
> logos, no watermarks, no graphic overlays. The image sits on a pure black app background,
> so the darker edges should fall off to black.

Aspect: heroes are tall portrait (around 4:5 to 9:16). Cards are portrait (around 3:4).
More rows are wide letterbox (around 16:9). Keep the key subject off center with room for a
text overlay in the lower left.

---

## Heroes

### `onboarding-hero`
A lone athlete mid effort, seen from the side in deep shadow, a single rim light tracing the
shoulder and arm. Sweat catching the light. Powerful and quiet. The lower third falls to near
black for a headline overlay. Tall portrait.

### `coach-hero`
An extreme close, abstract detail of a runner's torso or a coach's hands resting on a knee,
rendered almost as sculpture in raking light. Precision and control. Generous dark negative
space on the left for a headline. Tall portrait.

---

## Explore collections (portrait cards, food forward)

### `explore-high-protein`
A single seared chicken breast or salmon fillet on a dark stone surface, one hard light from
the side, steam barely visible. Minimal, no garnish clutter.

### `explore-breakfast`
A bowl of oats or two soft eggs on dark ceramic, morning light raking across from one side,
deep shadows. Calm and simple.

### `explore-smart-snacks`
A small handful of almonds or a single cut apple on slate, top down, hard shadow, lots of
empty dark space around it.

### `explore-lean-protein`
A piece of white fish or a tin of tuna styled minimally on a dark surface, clinical and clean,
single light.

### `explore-whole-grains`
A scatter of cooked grains or a cut loaf of dark bread, close and textural, side light picking
out the grain.

### `explore-greens`
A single head of broccoli or a few raw greens on black, dramatic single light, almost a
portrait of the vegetable.

---

## Article cards (portrait, editorial mood, less literal)

### `article-protein-basics`
A close abstract of meat or fish texture under hard light, almost monochrome.
### `article-calorie-deficit`
An empty plate on a dark table, single light, a study in restraint and space.
### `article-reading-labels`
A close, shadowy detail of a hand holding a package, the label out of focus, moody.
### `article-fiber`
A pile of raw vegetables and oats on black, textural, low key.
### `article-eating-out`
A dim restaurant table from above, one plate, deep shadow, cinematic.
### `article-weight-fluctuation`
An abstract of a bathroom scale in raking light, mostly shadow, quiet.
### `article-protein-leverage`
A protein forward plate built simply, side light, strong shadows.
### `article-consistency`
A single running shoe or a folded towel in hard light against black, disciplined and plain.

---

## More rows (wide letterbox)

### `more-goals`
An abstract uphill path or a figure walking into light, wide, lots of dark sky.
### `more-health`
A close of a wrist with a watch or a heartbeat of light across black, minimal.
### `more-favorites`
A small still life of a few favorite foods on dark stone, wide, calm.
### `more-custom`
A clean overhead of a notebook and a single ingredient, wide, low key.
### `more-export`
An abstract of soft light through a window onto a dark surface, calm and private.
### `more-about`
A wide minimal landscape of fog and dark hills, editorial, lots of space.

---

## Home meal accents (small square, optional, only if meal thumbnails are enabled later)

### `meal-breakfast` / `meal-lunch` / `meal-dinner` / `meal-snack`
A single representative dish for each, top down on dark ceramic, one hard light, tight crop,
square.

---

## App icon

### `app-icon`
Not a photo. A pure black square with a single white letterspaced wordmark feel. Generate a
clean white geometric mark on black that reads as a confident, minimal monogram for a premium
tracker. Flat, no gradient, no bevel. Square, 1024 by 1024.
