# Requirements: md2html

## Introduction

`md2html` converts Markdown to HTML: a documented subset of CommonMark plus
GitHub-style tables, written as an HTML fragment or a whole page. It is the
dual-mode project of the loup-cmd series that shows a two-pass parser, and
its golden-file corpus runs through both lanes of the same `host.dual`
source: `loup run` and the native binary.

## Requirements

### Requirement 1: Input and output

**User Story:** As a user, I want to convert a file or a pipe and write the
result where I choose.

#### Acceptance Criteria

1. WHEN a FILE is given, THE program SHALL read it; WHEN none is given or
   FILE is `-`, THE program SHALL read standard input.
2. THE program SHALL write the HTML to standard output, or to the file given
   with `-o`/`--output`.
3. THE program SHALL accept `\n` and `\r\n` line endings; a final newline
   SHALL NOT add an empty line.
4. WHEN the input or template does not exist or is a directory, or the
   output's directory does not exist or the output is a directory, THE
   program SHALL print `md2html: PATH: REASON` and exit with status 1.

### Requirement 2: Blocks

**User Story:** As a writer, I want the block structure of my document.

#### Acceptance Criteria

1. ATX headings (`#` to `######`, optional closing `#`s) and setext headings
   (`===`, `---` underlines) SHALL become `<h1>`–`<h6>`.
2. Paragraphs SHALL be separated by blank lines and SHALL end at a heading,
   fence, block quote, thematic break, table, or a list item that may
   interrupt a paragraph (a bullet, or an ordered item numbered 1).
3. Fenced code (three or more backticks or tildes, with an info string
   whose first word becomes `class="language-WORD"`) and indented code (four
   spaces or a tab) SHALL become `<pre><code>`, content escaped.
4. Block quotes (`>`, with lazy continuation lines) SHALL become
   `<blockquote>` and may contain any blocks.
5. Bullet lists (`-`, `+`, `*`) and ordered lists (`1.` or `1)`, with
   `start` when not 1) SHALL nest by indentation; a list SHALL be loose
   (paragraphs in `<p>`) when its items are separated by blank lines or an
   item holds two blocks separated by a blank line, else tight.
6. Thematic breaks (three or more `-`, `*` or `_`) SHALL become `<hr />`.
7. Tables (a header row, a delimiter row of `---` cells with optional `:`
   for alignment, body rows) SHALL become `<table>` with `<thead>`, a
   `<tbody>` when there are body rows, and `style="text-align:..."` on
   aligned columns; body rows SHALL be padded or cut to the header's width,
   and `\|` SHALL be a literal pipe.
8. Link reference definitions (`[label]: destination "title"`, one line)
   SHALL be collected and SHALL produce no output.

### Requirement 3: Inlines

**User Story:** As a writer, I want emphasis, code, links and images.

#### Acceptance Criteria

1. `*`/`_` emphasis and `**`/`__` strong emphasis SHALL follow CommonMark's
   delimiter rules (left/right flanking, intraword `_`, the rule of 3).
2. Code spans SHALL use matching backtick runs and SHALL contain no other
   markup.
3. Inline links and images `[text](destination "title")` and reference
   links (`[text][label]`, `[label][]`, `[label]`) SHALL be resolved; links
   SHALL not contain links; image alt text SHALL be the plain text.
4. Autolinks `<scheme:...>` and `<user@host>` SHALL become links. Link
   destinations SHALL be percent-encoded as cmark does: every character
   other than letters, digits, `-._~;/?:@&=+$,!*'()#%` becomes `%XX` per
   UTF-8 byte.
5. Backslash escapes of ASCII punctuation, hard line breaks (two trailing
   spaces or a backslash) and soft breaks SHALL follow CommonMark.
6. Numeric entities (1 to 7 decimal or 1 to 6 hexadecimal digits) and
   common named entities SHALL be decoded; unknown ones SHALL be printed as
   text.
7. Raw HTML SHALL be escaped, never passed through, and all text and
   attribute values SHALL be HTML-escaped.

### Requirement 4: Pages

**User Story:** As a user, I want a complete HTML page when I need one.

#### Acceptance Criteria

1. WHEN `-s`/`--standalone` is given, THE program SHALL wrap the HTML in a
   built-in page with a UTF-8 charset and a title.
2. WHEN `-t FILE`/`--template FILE` is given, THE program SHALL use FILE as
   the page, replacing `{{title}}` and `{{body}}` (implies `-s`).
3. THE title SHALL be `--title TEXT` (escaped; implies `-s`), else the
   plain text of the first heading of the highest level, else the input's
   file name without its extension, else `Untitled`.

### Requirement 5: Command line

**User Story:** As a shell user, I want predictable options and statuses.

#### Acceptance Criteria

1. Options SHALL be accepted anywhere before `--`, as `-x VALUE`,
   `--name VALUE` or `--name=VALUE`.
2. `--help`/`-h` SHALL print the usage and `--version`/`-V`
   `md2html (loup-cmd-md2html) 0.1.0`.
3. THE program SHALL exit with 0 on success, 1 on a file error, and 2 on a
   usage error (unknown option, missing value, more than one FILE), printing
   `Try 'md2html --help' for more information.` after a usage error.

### Requirement 6: Two lanes, one corpus

**User Story:** As a Loup developer, I want proof that the interpreted and
native builds of the same source agree.

#### Acceptance Criteria

1. `tests/fixtures/` SHALL hold Markdown inputs and the expected HTML for
   each feature above.
2. `make parity` SHALL convert every fixture with `loup run` and with the
   native binary, and SHALL fail unless both produce the expected HTML byte
   for byte.
