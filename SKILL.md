---
name: betheme-wordpress
description: Build, troubleshoot, and deploy cinematic scroll heroes and custom content in WordPress BeTheme/BeBuilder sites. Use when working with BeTheme Global Sections, BeBuilder live editor, scroll-scrub frame sequences, sprite sheet heroes, WordPress REST API content updates, BeBuilder Code elements, mobile optimization, or diagnosing WordPress content-mangling issues (wptexturize, entity encoding). Covers the full workflow from frame asset preparation through WordPress deployment.
---

# BeTheme WordPress Development

Build and deploy cinematic scroll heroes and custom interactive content on WordPress sites running BeTheme/BeBuilder.

## Critical WordPress Gotchas

### WordPress Mangles JavaScript in `the_content`

WordPress `wptexturize` and content filters convert characters inside `<script>` tags embedded in post content:

| Character | Gets Converted To | Breaks JS? |
|-----------|-------------------|------------|
| `&&`      | `&#038;&#038;`    | YES — fatal syntax error |
| `""`      | smart quotes      | YES in some contexts |
| `--`      | em dash           | Sometimes |
| `...`     | `&hellip;`        | Rarely |

**Workarounds (use ALL of these):**
- Replace `&&` with nested `if` statements: `if (a) { if (b) { ... } }`
- Replace `condition && action()` with `if (condition) { action(); }`
- Avoid template literals (backticks) — use string concatenation
- Use `var` instead of `let`/`const` for maximum compatibility
- Test the deployed page source through `node --check` after every push

### WordPress REST API Content Push

Use the REST API with Application Passwords to update page content programmatically. See `references/wp-push-script.py` for the complete script.

Always verify after push:

```bash
curl -s "https://site.com/page/" | python3 -c "
import sys, re
html = sys.stdin.read()
start = html.find('YOUR_FUNCTION_NAME')
s = html.rfind('<script>', 0, start)
e = html.find('</script>', start)
content = html[s+8:e]
with open('/tmp/check.js','w') as f: f.write(content)
" && node --check /tmp/check.js
```

### BeBuilder Section Conflicts

BeBuilder stores its own content in `mfn-page-items` post meta, rendered ABOVE `the_content`. If both exist, the page shows BeBuilder content first, then WordPress content.

**To remove BeBuilder content:** Open BeBuilder live editor, delete all sections, click Update. The AJAX save action is `updatevbview` with `sections=[]`.

**To coexist:** Use ONLY BeBuilder OR only `the_content` block — never mix for the same visual area.

## Scroll-Scrub Frame Sequence — Production Pattern

Read `references/scroll-hero-production.html` for the complete, WordPress-safe implementation.

Key architecture decisions:
- Canvas-based rendering (not `<img>` swapping) for smooth 60fps
- `position: sticky` container with tall scroll range (300vh desktop, 250vh mobile)
- Preloader with progress bar while frames load
- Mobile: load every-other-frame (halves memory and bandwidth)
- Lerp-smoothed frame interpolation for buttery scroll feel
- `orientationchange` handler for device rotation
- Multiple init strategies (DOMContentLoaded + load + setTimeout retries)
- Dimension-check guard: if canvas has 0 dimensions, retry after 100ms

## Mobile Optimization Rules

- Detect mobile: `window.innerWidth < 768` or UA sniffing
- Reduce frame count (load every 2nd frame on mobile)
- Shorter scroll range: 250vh instead of 300vh
- Faster lerp speed: 0.25 (mobile) vs 0.12 (desktop)
- Handle `orientationchange` with 300ms delay before resize
- Use passive scroll listeners: `{ passive: true }`
- GPU-accelerate canvas: `will-change: transform; transform: translateZ(0)`
- Never hide the canvas on mobile — scroll-scrub works with touch events

## Frame Asset Preparation

See `references/frame-prep.sh` for the complete script. Key steps:

1. Extract frames from video: `ffmpeg -i input.mp4 -r 15 frames/frame-%03d.jpg`
2. Optimize: `convert "$f" -quality 80 -resize 1920x1080 "$f"`
3. Upload via WP REST API media endpoint
4. Use the returned URLs in your CDN_BASE path

## BeBuilder Workflow

1. Prefer native BeBuilder elements (Section, Wrap, Fancy Heading, Button)
2. Use Code element only for scroll-driven JS that native tools cannot do
3. Use Global Sections for reusable heroes
4. Set `max_input_vars` to 10000+ in PHP if BeBuilder refuses to save
5. Use Layer Navigator to diagnose layout issues
6. Test on real mobile devices — emulators miss touch scroll behavior

## Deployment Checklist

- [ ] Script passes `node --check` on the live page source
- [ ] No `&#038;` entities in JavaScript (grep for it)
- [ ] Canvas renders on first load (no blank state)
- [ ] Preloader shows and dismisses correctly
- [ ] Scroll animation works on desktop Chrome, Safari, Firefox
- [ ] Scroll animation works on iOS Safari and Android Chrome
- [ ] No lorem ipsum or BeBuilder placeholder content visible
- [ ] Frame images are accessible (no 404s)
- [ ] Page loads under 5s on 4G connection
- [ ] `max_input_vars` is 10000+ if using BeBuilder

## Reference Files

- `references/scroll-hero-production.html` — Complete WordPress-safe scroll-scrub hero. Use as starting template for any frame sequence hero.
- `references/wp-push-script.py` — Python script to push HTML content to WordPress pages via REST API.
- `references/frame-prep.sh` — Shell script for extracting and optimizing video frames.
