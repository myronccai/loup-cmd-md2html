# AGENTS.md

This repository is `md2html`, a Markdown to HTML converter (a CommonMark
subset plus tables) written in the Loup programming language, as part of
the loup-cmd series of example applications. It is a `host.dual` project:
the same sources run under `loup run` and as a native executable, and
`make parity` checks both against a golden corpus.

## Skills

| Skill | Location | Use it when |
|-------|----------|-------------|
| `loup-programmer` | [skills/loup-programmer/SKILL.md](skills/loup-programmer/SKILL.md) | Writing, reviewing, debugging or explaining Loup code: `.lpscr`, `.loup`, `.lphc`, `.lpweb` or `.lpfree` source files, `.lppkg` manifests, `@mode(...)` directives, or the `loup` / `loup-bootstrap` commands. |

Read `skills/loup-programmer/SKILL.md` before writing or changing any Loup code
in this repository. It links to detailed references under
`skills/loup-programmer/references/` for syntax, types and ownership, execution
modes and projects, errors and diagnostics, the standard library, and common
mistakes. Load those only as needed.

## Code layout

```text
.
├── package.lppkg                # Loup manifest: name, version, toolchain, [build] entry, [test] pattern
├── Makefile                     # run, check, test, build, e2e, parity, ci, clean
├── source/                      # all Loup code; modules import each other by path from here
│   ├── main.loup                # entry point: func main() calls run(runtime.args())
│   ├── appinfo.loup             # APP_NAME, APP_VERSION, APP_SUMMARY, exit statuses
│   ├── cli/
│   │   ├── args.loup            # struct Options, parse_args()
│   │   ├── usage.loup           # usage(), version_line()
│   │   └── app.loup             # run(): parse, --help/--version, run_md2html, exit status
│   ├── commands/
│   │   └── md2html.loup         # run_md2html(), convert(), page_title(), fill_template()
│   └── markdown/
│       ├── text.loup            # escape_html, indent_of, remove_columns, normalize_label, strip_tags
│       ├── blocks.loup          # pass 1: enum Block, Refs, parse_blocks(), parse_document()
│       ├── inlines.loup         # pass 2: render_inline() (delimiter stack, links)
│       └── render.loup          # render_block(), markdown_to_html(), first_heading()
├── tests/
│   ├── *_test.loup              # unit tests: func test_*(): void
│   ├── e2e.sh                   # end-to-end tests of the native binary
│   ├── parity.sh                # the corpus through loup run and the native binary
│   └── fixtures/                # golden corpus: NAME.md and the expected NAME.html
├── specs/md2html/               # requirements.md, design.md, tasks.md
├── skills/loup-programmer/      # the Loup skill and its references
├── .github/workflows/ci.yml     # installs Loup and runs `make ci`
└── build/                       # build output (git-ignored)
```

## Build, run and test

Prerequisites: Loup 1.26.0 (`loup` and `loup-bootstrap` on `PATH`), `make`,
and `clang` 17 or later for native builds.

Loup Lite comes from <https://github.com/code-craft-ai-company/loup-releases>;
[README.md](README.md#installing-loup-lite) has the install commands.

| Task | Command | Notes |
|------|---------|-------|
| Run from source | `make run ARGS="README.md"` | `loup run source/main.loup -- ARGS` |
| Type-check | `make check` | checks `source/main.loup` and every module it imports; tests are not checked |
| Run all tests | `make test` | every `tests/*_test.loup`, sequentially |
| Run matching tests | `make test TEST_ARGS="--filter table"` | tests whose name contains `table` |
| Run one test file | `make test TEST_ARGS="--file tests/inlines_test.loup"` | |
| Build | `make build` | native binary at `build/md2html` |
| Run the binary | `build/md2html README.md` | |
| End-to-end tests | `make e2e` | runs `tests/e2e.sh build/md2html` |
| Parity | `make parity` | every `tests/fixtures/*.md` through `loup run` and `build/md2html`, compared with `*.html` |
| Everything CI runs | `make ci` | check, test, build, e2e, parity, then `build/md2html --version` |
| Clean | `make clean` | removes `build/` and `.temp/` |

Run `make ci` before reporting a change as done. `loup run` and the native
build do not support the same things, so a change can pass `make test` and
still fail `make build` or `make parity`.

Do not call `loup test` or `loup check` directly on Linux x86-64. There `loup`
is the self-hosted driver: it refuses `check`, and its test runner cannot
resolve this project's imports. The Makefile uses `loup-bootstrap` (Stage0) for
both, and sets `LOUPPATH=source` for tests. Tests run with `--no-parallel`.

## Making a change

1. Update the spec in `specs/md2html/` (see [specs/README.md](specs/README.md)).
2. Change the code under `source/`.
3. Add or update unit tests in `tests/`, cases in `tests/e2e.sh`, and a
   fixture pair in `tests/fixtures/` for new Markdown behaviour. Write the
   expected `.html` by hand or from a CommonMark implementation you trust
   (the corpus matches markdown-it's CommonMark mode with tables on and raw
   HTML off), and check it, then run `make parity`.
4. Run `make ci`.
5. Tick the finished tasks in `specs/md2html/tasks.md`.

Keep behaviour in pure functions that return values (`markdown_to_html`,
`convert`) so unit tests can check it; only `run_md2html` reads, writes and
prints.

## Conventions

- Every source file is `@mode(host.dual)` with the `.loup` extension. Only
  `source/main.loup` has a `main()`.
- Modules import each other by path from `source/`:
  `from markdown.blocks import (Block);`. Tests import them the same way. Do
  not use relative imports (`from .args import ...`): the self-hosted
  `loup run` on Linux x86-64 fails on them.
- Native-build pitfalls in Loup 1.26.0 that this code works around:
  - construct each struct in one module only (a struct built both in its
    own module and in another one is corrupted);
  - write a `match` that builds a string in statement form, with a
    `return` in each arm;
  - do not call methods on the result of `slice` (`xs.slice(i).index_of(x)`
    does not lower); bind it first or loop;
  - check `exists`/`isDir` before reading or writing: native `IoError`s
    cannot be caught;
  - `list.is_empty()` does not compile natively; use `len() == 0`;
  - give a comprehension's source list its type (`let parts: list[string] =
    s.split(...)`): over an unannotated `let` it crashes natively.
- A `"""` string cannot initialise a `const` (use a function, as
  `default_template` does), and its last line has no newline.
- A type alias works in its own module's signatures only: imported, it
  is an "undefined type" in function signatures (`Html` in text.loup is
  private for that reason).
- `template` is a reserved word: the template option's field is
  `page_file`.
- Struct fields read from another module must be `pub`; fields that are
  assigned must be `var`.
- Keep `APP_VERSION` in `source/appinfo.loup` equal to `version` in
  `package.lppkg`.
- The skill's examples use the `loup init` layout (`src/`, `tests/`, and
  `from ..src.x import` in tests). This project uses `source/` and
  `tests/` with plain imports; follow this file.
- The skill documents toolchain 1.25.1; this project targets 1.26.0. When
  they disagree, trust the toolchain's behaviour.
