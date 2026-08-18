# Project Memory — petzi53.github.io

## Overview

**"Thought Splinters"** — Peter Baumgartner's personal English-language learning journal / Quarto blog.

- **Live site:** https://peter-baumgartner.net
- **GitHub repo:** https://github.com/petzi53/petzi53.github.io
- **Output:** `docs/` (deployed via GitHub Pages; CNAME file present)
- **License:** CC BY 4.0

---

## Project Structure

```
petzi53.github.io/
├── _quarto.yml            # Site-wide Quarto config
├── AGENTS.md              # This memory file
├── _archive/              # ⚠ Do not analyse contents; stores ephemeral artefacts
├── _extensions/           # Quarto extensions (e.g. iconify)
├── _freeze/               # Frozen computation outputs
├── data/
│   ├── WID/               # World Inequality Database data
│   └── my_llm_chat_context.txt   # System prompt / context for AI sessions
├── docs/                  # Rendered output (GitHub Pages)
├── img/                   # Shared images
├── posts/                 # Blog posts (one folder per post)
│   └── _metadata.yml      # Shared post metadata (freeze, comments, lightbox)
├── R/
│   ├── ai_setup.R         # AI chat session setup (ellmer + Anthropic)
│   ├── coins_generation.R # COinS metadata generator for Zotero
│   ├── get_claude_models.R# List available Anthropic models via ellmer
│   └── helper.R           # Shared utility functions
├── .Rprofile              # Project-level R options (coins.lang, coins.license)
├── .gitignore
├── styles.css
├── glossary.css
├── index.qmd              # Blog listing page
├── about.qmd
├── archive.qmd
├── contact.qmd
├── disclaimer.qmd
├── privacy.qmd
├── quarto-blog.qmd        # Tutorial: create a Quarto blog
└── zotero-obsidian-annotations.qmd  # Tutorial: Zotero-Obsidian workflow
```

---

## Quarto Configuration (`_quarto.yml`)

- **Type:** website, output to `docs/`
- **Freeze:** `auto`
- **Theme:** `default` HTML theme
- **CSS:** `styles.css`, `glossary.css`
- **TOC:** depth 5, expand 4
- **Google Analytics:** G-CLE95GVN04
- **Comments:** Hypothesis (annotation sidebar)
- **Post comments:** Utterances (`petzi53/blog-comments` repo) — set in `posts/_metadata.yml`
- **Lightbox:** enabled for all posts (zoom effect)
- **Cookie consent:** enabled
- **Extensions:** iconify (fa6-brands icons in navbar)

### Custom crossref labels

| Key   | Label used  |
|-------|-------------|
| `def` | Definition  |
| `lem` | Resource    |
| `cnj` | R Code      |
| `prp` | Procedure   |

---

## R/ai_setup.R — AI Chat Session Setup

Configures `ellmer`-based chat sessions against the Anthropic API.

### Key paths (via `here::`)

| Variable            | Path                              |
|---------------------|-----------------------------------|
| `my_context_path`   | `data/my_llm_chat_context.txt`    |
| `my_chat_rds_path`  | `_archive/_rds`                   |
| `my_chat_txt_path`  | `_archive/_txt`                   |

### Model registry (as of June 2026)

| Alias    | Model ID                    | Intended use                        |
|----------|-----------------------------|-------------------------------------|
| `opus`   | `claude-opus-4-6`           | Complex statistical reasoning        |
| `sonnet` | `claude-sonnet-4-6`         | Coding, Shiny, standard analysis (default) |
| `haiku`  | `claude-haiku-4-5-20251001` | Batch coding, simple classifications |

### Workflow

```r
source(here::here("R/ai_setup.R"))   # load setup; default model = sonnet

start_chat("ellmer")   # open live_browser() session
start_chat("chattr")   # open chattr Shiny app

set_opus()    # switch to Opus
set_sonnet()  # switch to Sonnet
set_haiku()   # switch to Haiku

my_save_chat("my-session-name")        # save to _archive/_rds/ and _archive/_txt/
my_restore_chat("my-session-name")     # restore from _archive/_rds/
```

The `browse_tool` (wrapping `fetch_url()` via `httr2` + `rvest`) is registered
automatically on every chat session, giving Claude web-browsing capability.

---

## R/coins_generation.R — COinS Metadata for Zotero

Generates COinS (ContextObjects in Spans) metadata and appends it as an R code
cell to a `.qmd` blog post. Allows Zotero to auto-import citation metadata from
the rendered page.

### Usage

With `source(here::here("R/coins_generation.R"))` added to the project-level
`.Rprofile`, open the target post in the editor and run:

```r
coins()
```

The `coins()` wrapper reads the active editor file via `rstudioapi` and calls
`generate_and_append_coins()`. Pass `backup = FALSE` to skip the `.bak` copy.

### Field resolution priority

1. Post YAML header
2. `_quarto.yml` (`blog-title`, `url`)
3. `.Rprofile` options (`coins.lang`, `coins.license`)
4. Omitted

### YAML → COinS field mapping

| YAML field         | COinS key         | Zotero field     |
|--------------------|-------------------|------------------|
| `title`+`subtitle` | `rft.title`       | Title            |
| `blog-title`       | `rft.source`      | Blog Title       |
| `url`              | `rft_id`          | URL              |
| `date` (year)      | `rft.date`        | Date             |
| `lang`             | `rft.language`    | Language         |
| `license`          | `rft.rights`      | Rights           |
| `description`      | `rft.description` | Abstract         |
| `author`           | `rft.au`          | Author           |

---

## R/helper.R — Utility Functions

| Function          | Signature                              | Purpose                                      |
|-------------------|----------------------------------------|----------------------------------------------|
| `my_glance_data`  | `(df, N=8, seed=42)`                   | N random rows + first & last row             |
| `save_data_file`  | `(chapter_folder, object, file_name)`  | Save `.rds` to `data/<folder>/`              |
| `pkgs_dl`         | `(pkgs, period="last-week", days=7)`   | CRAN download counts via `cranlogs`          |

Also sets glossary path: `../glossary-pb/glossary.yml` (relative to project root).

---

## .Rprofile (project-level)

Sets options used by `coins_generation.R`:

```r
options(
  coins.lang    = "en",
  coins.license = "CC BY 4.0"
)
```

---

## Notes on User-level ~/.Rprofile

Sets options for `blogdown.*`, `devtools.*`, `usethis.*`, `quartopost.*`,
glossary path, and an R version check via `rversions`.
