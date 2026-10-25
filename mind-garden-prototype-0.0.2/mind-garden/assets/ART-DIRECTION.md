# Visual direction, version 0.0.2

The user rejected the first procedural graphics entirely. The new app is portrait,
UI-first, with a large interactive illustration and controls at the bottom.
The art below is a new proposal, not an assertion that the user's final brand style
has been approved. All four assets were generated with the built-in image-generation
tool, not the CLI. Original output files are copied unchanged into this project.
They are displayed by Godot with nearest-neighbor texture sampling.

## Main garden prompt

Use case: stylized-concept. Asset type: a production-quality pixel-art background for a portrait Android mindfulness journal, NOT a mockup, NOT a phone screenshot. Create ONE tall portrait image, aspect ratio 9:16, 1024x1792 or nearest portrait size. Entire image is the art, no text, no UI, no borders, no frames. A small contemplative Japanese Zen garden seen from a fixed elevated 3/4 view, an intimate secret garden in blue-hour twilight. Composition: top 20 percent breathing room with misty indigo sky and layered distant silhouettes. Central upper area has a single graceful mature bonsai/pine with beautifully sculpted dark foliage, moss-covered stones and sparse flowers. Lower central right has a small jade-blue pond, a few waterlilies, restrained rippled reflections; a narrow gently curving stone path makes a small quiet clearing in the lower center at 65 percent image height for a tiny walking player sprite to be layered later. One stone lantern with muted warm amber light. Garden feels intimate, minimal, art directed and inhabited, not a dense ornamental flower park. Low foreground plants gradually fade to very dark navy ground by bottom 18 percent, to leave quiet space for app controls later. Color direction from Andres' Buddhism in Plain Language / Буддизм по-пацански channel: cool neutral dark base, deep navy blue and blue-gray shadows, muted violet accents, small restrained warm amber highlights, turquoise reflections. Rich high-contrast focal details and readable silhouettes, never flat muddy green. Authentic excellent late SNES / Game Boy Advance Japanese RPG BACKGROUND pixel art with deliberate visible square pixels, cohesive pixel grid, sharp pixel clusters, hand-placed dithering, sophisticated pixel edge work and beautiful limited palette. Think a master pixel artist's atmospheric JRPG shrine scene, modest Pokemon/Zelda era inspiration without copying any specific game. Despite the portrait output, design as if native artwork were about 270x480 enlarged nearest-neighbor so the pixels are recognisably intentional. NO smooth painterly rendering, no vector-looking blobs, no blurry pixel filter on a painting, no gradients with airbrush, no 3D rendering, no toy plastic, no green monochrome, no literal Game Boy console, no HUD, no Buddha statue, no humans, no animal character baked into the scene. Background only. This replaces rejected low-quality procedural art completely.

## Shared prefix for the neighboring screens

Input image 1 is `scene_garden.png`.

Asset type: actual portrait pixel-art background for the same Android Buddhist journaling app, NOT a mockup or phone. Use case: stylized-concept. Input Image 1 is a STYLE AND PALETTE reference only; create a new neighboring part of the same garden. Same 9:16 portrait composition, same crisp intricate authentic JRPG pixel art, clearly visible square pixel clusters, dark navy/blue-gray shadows, muted violet and restrained amber light. Absolutely NO text, no interface, no people or animals baked in, no watermarks, no 3D, no airbrushed painting, no vector blobs. Top 15 percent distant mist/sky breathing space. Bottom 18 percent fades naturally into dark navy foreground to accommodate later app controls. Maintain atmospheric contrast and beautiful fine pixel detail from Image1.

## Journal screen suffix

Create the LEFT neighboring screen, a quiet place for writing: a small Japanese wooden open-air writing nook next to this same garden, viewed from fixed elevated 3/4 angle. A low old wood desk with blank cream paper, inkstone, slender brush, a closed plain book and a softly glowing small paper lantern. A mossy stepping path from the lower center approaches the writing desk in the middle of the composition around 55 percent image height. Behind it a bamboo fence, a graceful tree, violet flowering branches and layered blue mountains at twilight. One focal desk, intimate uncluttered composition. Empty path/clearing at 65 percent image height for a separate tiny player sprite. The desk's paper must be blank, absolutely NO writing or lettering.

## Practice screen suffix

Create the RIGHT neighboring screen, a place for Buddhist meditation: a modest open wooden pavilion roof framed by branches and blue mountains, a square natural woven tatami platform and one round muted purple zafu cushion, a small bronze singing bowl and wooden striker next to the cushion, one softly glowing amber lantern. The pavilion in the central image around 55 percent image height has a clear readable silhouette with vacant space around it. A short quiet stone path enters from lower center and ends at the cushion. Tiny pond and moss stones at the side. A few violet wisteria flowers and a pine branch frame the upper scene without crowding. Fixed elevated 3/4 angle, intimate contemplative mood. No Buddha statue, no people or animals baked in. Empty cushion for a separate player sprite. Keep foreground low contrast and dark.

## Character atlas prompt

Use case: stylized-concept. Asset type: precise transparent sprite atlas for a portrait JRPG-pixel mindfulness app. Generate a single 3-column by 2-row sprite sheet, overall landscape aspect ratio 3:2, three EXACTLY equally sized square cells in each row, no visible cell boundaries or text. Genuine alpha transparent background outside the sprites. Each sprite must fit inside the CENTRAL 50% width and 70% height of its cell and stand on an identical baseline at 82% of cell height. Row1 all three cells are the SAME tiny adult male pixel character, dark ordinary short hair, small glasses, dark charcoal sweater, muted violet trousers, warm light skin. Three frames left to right: idle slightly facing right, walking right left leg forward, walking right right leg forward. Identical head size and scale and clothes in all frames. Refined cohesive late-SNES/GBA JRPG pixel art, deliberate square pixel clusters, limited 12-ish colors per sprite, dark blue-gray outlines with some amber edge light and subtle violet shading. Native character design should be around 24x40 real pixels enlarged uniformly, NOT a painting. Row2 all three cells are the SAME small cream-gray domestic CAT (not a humanoid) facing right, big readable ear silhouette and curved tail. Frames: idle standing, walking left paw forward, walking right paw forward. Cat about half player height. Uniform scale across cat frames. Plain atlas without ground tiles, props, shadows on a background, decorative elements, captions, numbers, padding marks or UI. NO checkerboard baked in, actual transparency. This sheet will be sampled by a game engine by dividing width by3 and height by2.

## Implementation notes

The generator's atlas has extra height in the player row. Godot reads three
512x600 player regions and three 512x424 cat regions; source pixels are unchanged.
The seated pose currently uses only the upper-body region. This remains a prototype
approximation, not a finished seated animation. Full character likeness is unapproved.
Backgrounds are single images. Reflections, weather, light changes, plants, player
and cat are separate runtime layers. Parallax and animated foliage are not implemented.
