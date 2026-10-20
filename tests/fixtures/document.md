# md2html

Converts **Markdown** to HTML. It handles the parts of
[CommonMark](https://commonmark.org) that most README files use.

## Install

1. Install Loup:

   ```sh
   curl -fsSL https://example.com/install.sh | sh
   ```

2. Build:

   ```sh
   make build
   ```

## Usage

| Option | Meaning |
|--------|---------|
| `-o FILE` | write to *FILE* |
| `-s` | a whole page |

> **Note:** raw HTML such as <script> is escaped.

- Fast enough
- Small: about 2,000 lines of Loup
- Tested against a [golden corpus][corpus]

---

[corpus]: tests/fixtures/ "The corpus"
