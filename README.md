# loup-cmd-md2html

A Markdown to HTML converter in [Loup](https://code-craft.ai/references/loup):
a documented subset of CommonMark plus tables, written as a fragment or a
whole page, built as a two-pass parser (blocks, then inlines).

Part of the **loup-cmd** series of example applications: classic Linux and
Windows commands, and projects for each Loup execution mode, each in its own
repository under [myronccai](https://github.com/myronccai?tab=repositories&q=loup-cmd).
This one is a `host.dual` project: the same source runs under `loup run`
and as a native binary, and a golden-file corpus checks both.

## Requirements

- [Loup Lite](https://github.com/code-craft-ai-company/loup-releases) 1.26.0
  or later; see [Installing Loup Lite](#installing-loup-lite).
- `make`, and `clang` 17 or later for the native build.

## Installing Loup Lite

This example is built and tested with **Loup Lite**, the free public build of
the Loup toolchain from [Code Craft AI](https://code-craft.ai), meant for
education and training. Code Craft AI publishes the official builds,
installers and signed checksums at
**<https://github.com/code-craft-ai-company/loup-releases>**, for Linux
(x86-64, arm64), macOS (Apple silicon, Intel) and Windows (x86-64).

Linux and macOS:

```sh
curl -fsSL https://github.com/code-craft-ai-company/loup-releases/releases/latest/download/loup-install.sh | sh
```

Windows (PowerShell):

```powershell
irm https://github.com/code-craft-ai-company/loup-releases/releases/latest/download/loup-install.ps1 | iex
```

The installer picks the archive for your machine, checks it against the
release's `SHA256SUMS`, unpacks it into `~/.loup`
(`%LOCALAPPDATA%\Programs\Loup` on Windows) and puts its `bin` directory on
your `PATH`; it needs no administrator rights. You get `loup`, the Stage0
compiler `loup-bootstrap` and the Wasm runtime `loup-launcher`. Open a new
shell and check:

```sh
loup --version             # loup 1.26.0 or later
```

CI installs the exact version it tests with, 1.26.0. To do the same:

```sh
curl -fsSL https://github.com/code-craft-ai-company/loup-releases/releases/download/v1.26.0/loup-install.sh | sh -s -- --version 1.26.0
```

To install by hand, download your platform's archive from the
[releases page](https://github.com/code-craft-ai-company/loup-releases/releases),
check it against `SHA256SUMS`, unpack it anywhere and add its `bin` directory to
`PATH`. The [loup-releases README](https://github.com/code-craft-ai-company/loup-releases#verify-a-download)
explains how to verify the Sigstore signature on `SHA256SUMS`.

Loup Lite leaves out Loup's cryptography library and the full set of Loup
packages; this example needs neither. Commercial use of Loup needs a
license: <https://code-craft.ai/loup/license>.

## Usage

```sh
make build                    # native binary: build/md2html
make ci                       # check, unit tests, build, e2e, parity
make run ARGS="README.md"     # run from source with loup run
```

```text
$ cat notes.md
# Release notes

Version **0.1** adds:

- tables, with `:---:` alignment
- [reference links][spec]

| Lane | Command |
|:-----|:--------|
| interpreted | `loup run` |
| native | `build/md2html` |

[spec]: https://spec.commonmark.org
$ build/md2html notes.md
<h1>Release notes</h1>
<p>Version <strong>0.1</strong> adds:</p>
<ul>
<li>tables, with <code>:---:</code> alignment</li>
<li><a href="https://spec.commonmark.org">reference links</a></li>
</ul>
<table>
<thead>
<tr>
<th style="text-align:left">Lane</th>
<th style="text-align:left">Command</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align:left">interpreted</td>
<td style="text-align:left"><code>loup run</code></td>
</tr>
<tr>
<td style="text-align:left">native</td>
<td style="text-align:left"><code>build/md2html</code></td>
</tr>
</tbody>
</table>
$ printf 'Hello *world* & <friends>\n' | build/md2html
<p>Hello <em>world</em> &amp; &lt;friends&gt;</p>
$ build/md2html -s --title 'My notes' notes.md | head -8
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>My notes</title>
</head>
<body>
<h1>Release notes</h1>
$ build/md2html missing.md; echo "exit $?"
md2html: missing.md: No such file or directory
exit 1
```

`md2html [OPTION]... [FILE]` reads FILE, or standard input when FILE is
missing or `-`, and writes the HTML to standard output.

| Option | Meaning |
|---|---|
| `-o`, `--output FILE` | write the HTML to FILE |
| `-s`, `--standalone` | write a whole page (doctype, `<head>` with a UTF-8 charset and a title, `<body>`) |
| `-t`, `--template FILE` | write a page from FILE, replacing `{{title}}` and `{{body}}` (implies `-s`) |
| `--title TEXT` | the page title (implies `-s`); by default the first heading, else the file name, else `Untitled` |
| `-h`, `--help` / `-V`, `--version` | help and version |

Exit status: `0` on success, `1` if a file cannot be read or written, `2`
for a usage error.

### Markdown supported

| Blocks | Inlines |
|---|---|
| ATX (`#`) and setext (`===`, `---`) headings | `*em*`, `_em_`, `**strong**`, `__strong__`, with CommonMark's delimiter rules |
| paragraphs, hard (two spaces, `\`) and soft line breaks | `` `code spans` `` |
| fenced (```` ``` ````, `~~~`, with a language) and indented code | `[links](/url "title")`, `![images](/src)` |
| block quotes, lazy continuation lines | reference links `[text][label]`, `[label][]`, `[label]` |
| bullet and ordered lists, nested, tight or loose | autolinks `<https://...>`, `<me@example.com>` |
| thematic breaks | backslash escapes, entities (`&copy;`, `&#35;`) |
| tables with column alignment | |
| link reference definitions | |

Raw HTML is escaped rather than passed through, so the output is safe to
embed in a page. Not supported: HTML blocks, multi-line reference
definitions, footnotes, task lists, strikethrough, bare-URL autolinks and
heading IDs.

## What this example shows

**One source, two lanes, one corpus.** The parser is `host.dual` Loup, so
`loup run` interprets the same files that `make build` compiles.
`tests/fixtures/` holds 13 Markdown files, one per feature plus a whole
document, each with the HTML it must produce, and `make parity` (part of
`make ci`) converts every one in both lanes and compares byte for byte:

```text
$ make parity
bash tests/parity.sh "loup" build/md2html
parity: 28 passed, 0 failed (2 lanes x 14 inputs)
```

The expected HTML follows cmark's and markdown-it's layout exactly. While
developing, the output was compared with markdown-it-py 3.0.0 (CommonMark
mode, tables on, raw HTML off) on the fixtures and on 300 other Markdown
files, the Loup books and the READMEs of this series, with no
differences. CI does not need markdown-it: the fixtures state the expected
output.

**A two-pass parser.** Pass 1 (`source/markdown/blocks.loup`) turns lines
into a tree of `Block` enum values. Containers are parsed by collecting
their lines, stripping the `>` or the list item's indentation, and parsing
the result recursively; reference definitions are gathered on the way.
Pass 2 (`source/markdown/inlines.loup`) runs on each leaf block's text: one
scan into pieces (escaped text, code spans, `*`/`_` delimiter runs with
their flanking flags, brackets), links resolved when a `]` finds its
bracket, then CommonMark's delimiter-stack algorithm pairs the emphasis.
Pass 1 must finish first because a link may use a definition that comes
later.

**What native builds of Loup 1.26.0 required:** each struct is constructed
in one module only (a struct built in two modules is corrupted), every
`match` that builds a string returns from its arms, files are checked
before they are read or written (native `IoError`s cannot be caught), and
`xs.slice(i).index_of(x)` is written as a loop (no native lowering).

## Layout

```text
source/main.loup               # entry point
source/appinfo.loup            # name, version, exit statuses
source/cli/args.loup           # options
source/cli/usage.loup          # --help and --version text
source/cli/app.loup            # run(): parse, convert, exit status
source/commands/md2html.loup   # input, pages and templates, output
source/markdown/text.loup      # escaping, character classes, tab columns
source/markdown/blocks.loup    # pass 1: blocks and reference definitions
source/markdown/inlines.loup   # pass 2: emphasis, code, links, images
source/markdown/render.loup    # blocks to HTML
tests/*_test.loup              # unit tests (make test)
tests/e2e.sh                   # end-to-end tests of build/md2html (make e2e)
tests/parity.sh                # the corpus through both lanes (make parity)
tests/fixtures/                # golden corpus: *.md and expected *.html
specs/md2html/                 # requirements, design, tasks
```

[AGENTS.md](AGENTS.md) has every build and test command and the conventions
for changing the code.

## License

[MIT](LICENSE), copyright 2026 Code Craft AI LLC. The Loup skill in
[`skills/loup-programmer/`](skills/loup-programmer/) is copied from the Loup
project and is not covered by this license; it keeps the Loup project's terms.
