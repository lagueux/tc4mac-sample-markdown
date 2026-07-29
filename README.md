# tc4mac Markdown plugin (viewer sample)

A [tc4mac](https://tc4mac.com) viewer plugin: Markdown files render as a
formatted page in Lister (F3) and Quick View (⌃Q).

## Build and install

```
./make-plugin.sh
```

That produces `Markdown.tcplugin`. In tc4mac open **Configuration ▸ Plugins ▸
Install…**, choose it, then switch it on.

## What to look at

A viewer plugin does **not** draw. It converts the file into something the
host already renders and hands that back, which is why it inherits Lister's
find, print, copy and appearance instead of reimplementing them — and why no
view is ever shared across the process boundary.

- `main.swift` — the two calls that matter: how much the plugin wants a file,
  and what it converts it into.
- `MarkdownRenderer.swift` — the conversion, kept pure and tested.

Two decisions worth copying into your own viewer:

**Answer honestly about files you half-recognise.** `.md` returns
`.preferred`; a file that merely *starts* like Markdown returns `.fallback`,
which beats a hex dump but loses to anything that really knows the format.

**Quick View gets the cheaper rendering.** It follows the panel cursor, so it
receives the raw text while a full Lister window gets the converted page.

The renderer escapes before it converts, so a document containing markup
cannot inject it into the rendered page — a viewer plugin sees untrusted
files by definition.

## Licence

MIT. See `LICENSE`.
