# Design: md2html

## Overview

`main()` passes `runtime.args()` to `cli.app.run`, which parses the options,
handles `--help` and `--version` and calls `commands.md2html.run_md2html`.
That reads the input, converts it, fills a page template if asked, and
writes the result. The conversion is two passes over the text:

```text
text --pass 1 (blocks.loup)--> Document{blocks: tree of Block, refs}
     --pass 2 (inlines.loup, per leaf block)--> HTML  (render.loup)
```

Pass 1 must finish before pass 2 starts, because a reference link may use a
definition that appears later in the document.

## Modules

| Module | Contents |
|---|---|
| `source/main.loup` | entry point: `run(runtime.args())` |
| `source/appinfo.loup` | name, version, summary, exit statuses |
| `source/cli/args.loup` | `Options`, `parse_args` |
| `source/cli/usage.loup` | `usage()`, `version_line()` |
| `source/cli/app.loup` | `run()`: parse, help/version, convert, exceptions to status 1 |
| `source/commands/md2html.loup` | `run_md2html`, `convert`, `page_title`, `fill_template`, `DEFAULT_TEMPLATE` |
| `source/markdown/text.loup` | character classes, `escape_html`, indentation and tab columns, labels, `strip_tags`, `encode_url` |
| `source/markdown/blocks.loup` | pass 1: `Block` enum, `Refs`, `parse_blocks`, `parse_document` |
| `source/markdown/inlines.loup` | pass 2: `render_inline` (code spans, delimiter runs, brackets, links, autolinks, entities, breaks) |
| `source/markdown/render.loup` | `render_block(s)`, `markdown_to_html`, `first_heading` |

## Pass 1: blocks

`parse_blocks(lines)` walks the lines and recognises, at each non-blank
line, indented code, an ATX heading, a fence, a thematic break, a block
quote, a list, a table, or else a paragraph (which may turn into a setext
heading, and may start with link reference definitions).

Containers are parsed by collecting and recursing. A block quote collects
its `>` lines (minus the marker) plus lazy continuation lines; a list item
collects its first line and every following line indented to the item's
content column (minus that indentation), blank lines, and lazy lines; the
collected lines go through `parse_blocks` again. `parse_blocks` also
reports whether a blank line separated two of its blocks, which with blank
lines between items decides whether a list is loose.

Tabs count to the next multiple of four (`indent_of`), and
`remove_columns` removes indentation by columns, turning a partly removed
tab into spaces and keeping tabs inside code.

## Pass 2: inlines

`render_inline(text, refs)` scans the text once into pieces: finished HTML
(escaped text, code spans, autolinks, breaks), delimiter runs of `*`/`_`
with their can-open/can-close flags from the flanking rules, and `[`/`![`
brackets. On `]` the nearest bracket is tried as a link or image: an inline
`(destination "title")`, then a full, collapsed or shortcut reference. On a
match, emphasis is resolved inside the link text, the pieces since the
bracket become one HTML piece, and (for links) earlier `[` brackets are
deactivated. Finally `process_emphasis` (CommonMark's algorithm, with the
rule of 3) pairs the remaining delimiters over the whole text, adding
`<em>`/`<strong>` tags to the delimiter pieces.

## Rendering

The renderer prints the same layout as cmark and markdown-it (one block per
line; tight list items without `<p>`; a block after a hidden paragraph on a
new line except code). The golden files in `tests/fixtures/` were checked
against markdown-it-py 3.0.0 in CommonMark mode with tables enabled and raw
HTML off, and so were 300 Markdown files of the Loup books and this series.

## What this example shows

- A two-pass parser: a recursive block parser that builds an enum tree,
  and an inline parser built on CommonMark's delimiter stack.
- HTML escaping everywhere, and raw HTML refused, so output is safe to
  embed.
- One source in two lanes: `make parity` runs the golden corpus through
  `loup run` and through the native binary.

## Deviations from CommonMark

- Raw HTML (inline and blocks) is escaped, not passed through.
- Link reference definitions must fit on one line.
- Only the common named entities are decoded (numeric ones all are); other
  names are printed as text.
- In link destinations only spaces and a few ASCII characters are
  percent-encoded; non-ASCII characters are kept.
- Not supported: HTML blocks, footnotes, task lists, strikethrough,
  extended autolinks (bare `www.` and URLs), heading IDs.

## Native-build constraints (Loup 1.26.0)

- Each struct is constructed in one module only (`Block`, `Refs`, `Blocks`,
  `Document` in `blocks.loup`; `Piece`, `Scanner`, `Target` in
  `inlines.loup`).
- `match` arms that build strings return from each arm.
- No method calls on the result of `slice` (`index_of` there has no native
  lowering); `list.is_empty()` is not used.
- Files are checked with `exists`/`isDir` before reading or writing, since
  native `IoError`s cannot be caught.

## Error handling

Usage errors (status 2) come from `parse_args`. File problems (status 1)
are detected before any read or write and reported as `md2html: PATH:
REASON`. Conversion itself cannot fail: any text is valid Markdown.

## Testing

- `tests/text_test.loup`, `tests/blocks_test.loup`,
  `tests/inlines_test.loup`, `tests/render_test.loup`: the helpers and both
  passes.
- `tests/md2html_test.loup`, `tests/args_test.loup`,
  `tests/app_test.loup`: pages, options, exit statuses.
- `tests/e2e.sh`: the native binary: input sources, `-o`, pages, templates,
  errors.
- `tests/parity.sh` with `tests/fixtures/`: 13 fixtures (and one through
  standard input) in both lanes against the golden HTML.
