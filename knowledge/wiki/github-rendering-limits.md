---
name: github-rendering-limits
description: GitHub sanitizes SVG in Markdown; glows are built from gradients because filters are not guaranteed to survive.
metadata:
  type: wiki
---

`docs/assets/hero.svg` is rendered by GitHub inside the README, which runs it
through an HTML/SVG sanitizer first.

**Avoid `<filter>`.** `feGaussianBlur` and friends are not guaranteed to survive
sanitization, and when they are dropped every glow disappears silently — the
image still renders, just flat and wrong. The hero builds all glow and haze from
**layered `radialGradient` stops fading to `stop-opacity="0"`**, which is plain
paint and always survives.

Confirmed to work: `linearGradient`, `radialGradient`, `clipPath`, `<style>`
blocks with classes, `transform="rotate(...)"`, `dominant-baseline`, `<title>`
and `aria-label`.

Fonts are not embedded — use a generic stack (`ui-sans-serif, -apple-system, …`)
and accept that metrics differ slightly per viewer. Centre text with
`text-anchor="middle"` rather than hand-computed offsets so a substituted font
cannot push it off-centre.

**Caching.** GitHub serves README images through its CDN at a stable URL, so a
changed image can appear stale in a browser for a while. Confirm what is
actually published by fetching the raw URL rather than trusting the page:

```bash
curl -s https://raw.githubusercontent.com/<owner>/<repo>/main/docs/assets/hero.svg \
  | grep -o 'viewBox="[^"]*"'
```

The image carries its own dark background, so it reads correctly under both
GitHub themes without a `<picture>` light/dark pair.

Related: [[naming-conventions]]
