# Standard Slide Assets

These files contain shared image assets for Reveal.js presentations:

- The image files in this folder are shared title and institution assets.

## Open locally

Do not double-click an HTML file. Browser security treats `file://` pages as
unique origins and can block Reveal.js, scripts, or local assets. Start a small
HTTP server from the repository root instead:

```powershell
& .\.venv\Scripts\python.exe -m http.server 8000 --directory slides
```

Then open:

- `http://localhost:8000/template/template.html`
- `http://localhost:8000/template/slides.html`
- `http://localhost:8000/analytical_data_processing_vibe_code_mcp/slides.html`

Stop the server with `Ctrl+C`.

## Minimal deck

Use `slides/slides.html` as the current inline CSS and JavaScript reference when
creating a new deck. The shared stylesheet and runtime assets are intentionally
not extracted yet.

## Standard structures

Use `class="slide"` on content sections:

```html
<section class="slide">
  <div class="slide-rule"></div>
  <h2>Slide heading</h2>
  <div class="slide-cards">
    <article class="slide-card">
      <h3>Topic</h3>
      <p>Short explanation.</p>
    </article>
    <article class="slide-card is-positive">
      <h3>Control point</h3>
      <p>Positive or highlighted explanation.</p>
    </article>
  </div>
  <div class="slide-footer">Project | Event | Date</div>
</section>
```

Available patterns:

- `title-slide` with `title-meta` and `title-logo`
- `slide-cards` containing `slide-card` and optional `is-positive`
- `slide-flow` with `slide-card` and `slide-arrow` children
- `slide-table` for comparison tables
- `slide-code` for code or workflow text
- `slide-callout` with optional `is-positive`
- `closing-slide` for the final discussion slide

Deck-specific CSS should remain inline until the reference deck has been
cleaned up and extracted incrementally.
