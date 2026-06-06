# R/ai_setup.R


# ── 1. Paths & context ──────────────────────────────────────────────────────

# Resolve all paths relative to the project root
my_context_path  <- here::here("data", "my_llm_chat_context.txt")
my_chat_rds_path <- here::here("_archive", "_rds")
my_chat_txt_path <- here::here("_archive", "_txt")

# Helper: check that a file exists, stop gracefully if not
check_file_exists <- function(path) {
    if (!file.exists(path)) {
        stop(
            "Required file not found:\n  ", path,
            "\nPlease create the file or correct the path before continuing.",
            call. = FALSE
        )
    }
    invisible(path)
}

# Helper: check that a directory exists, stop gracefully if not
check_dir_exists <- function(path) {
    if (!dir.exists(path)) {
        stop(
            "Required directory not found:\n  ", path,
            "\nPlease create the directory or correct the path before continuing.",
            call. = FALSE
        )
    }
    invisible(path)
}

# Run the cheks
# 1. Verify the context file exists
check_file_exists(my_context_path)

# 2. Verify the RDS archive directory exists
check_dir_exists(my_chat_rds_path)

# 3. Verify the TXT archive directory exists
check_dir_exists(my_chat_txt_path)

message("All paths validated successfully. Continuing...")

# Read the Context File
context_text <- readr::read_file(my_context_path)

# Quick sanity check: show character count
message("Context file loaded — ", nchar(context_text), " characters read.")

# ── 2. Model registry ───────────────────────────────────────────────────────
# Short friendly names → exact Anthropic model IDs (May 2025)

my_models <- list(
    opus   = "claude-opus-4-6",
    sonnet = "claude-sonnet-4-6",
    haiku  = "claude-haiku-4-5-20251001"
)

# ── 3. Default model ─────────────────────────────────────────────────────────

options(.my_ai_model = my_models[["sonnet"]])

cat(
    "✅ ai_setup.R loaded.\n",
    "   Default model   :", getOption(".my_ai_model"), "\n",
    "   Switch models   : set_opus() | set_sonnet() | set_haiku()\n",
    "   Start session   : start_chat('ellmer') | start_chat('chattr')\n"
)

# ── 3a. URL fetching function ─────────────────────────────────────────────────
# Performs an HTTP GET request and returns page content as plain text.
# For HTML pages, rvest strips the tags to return readable text only.
# For raw resources (GitHub raw files, CSV, plain text), the body is
# returned directly. A graceful error string is returned on HTTP failure
# so Claude can report the problem rather than the tool crashing.

fetch_url <- function(url) {

    # Send request with a browser-like user agent to avoid bot-blocking
    response <- httr2::request(url) |>
        httr2::req_headers(
            `User-Agent` = "Mozilla/5.0 (compatible; ellmer-tool/1.0)"
        ) |>
        httr2::req_error(is_error = \(resp) FALSE) |> # handle errors gracefully
        httr2::req_perform()

    # Return an informative string on HTTP 4xx / 5xx rather than stopping
    status <- httr2::resp_status(response)
    if (status >= 400) {
        return(paste0("Error: HTTP status ", status, " for URL: ", url))
    }

    # Choose parser based on content type
    content_type <- httr2::resp_content_type(response)

    if (stringr::str_detect(content_type, "html")) {
        # Strip HTML tags; rvest::html_text2() collapses whitespace cleanly
        response |>
            httr2::resp_body_string() |>
            rvest::read_html() |>
            rvest::html_text2()
    } else {
        # Plain text, JSON, CSV, Markdown, etc. — return body as-is
        httr2::resp_body_string(response)
    }
}

# ── 3b. Browse tool descriptor ───────────────────────────────────────────────
# Wraps fetch_url() in an ellmer tool descriptor. Claude reads the
# description at runtime to decide autonomously when to call the tool.
# Defined once here at source time; registered in every chat session
# created by get_anthropic_chat() in section 5.

browse_tool <- ellmer::tool(
    fun         = fetch_url,
    name        = "fetch_url",
    description = paste(
        "Fetches the content of a web page or raw file from a given URL.",
        "Use this tool whenever the user provides a URL and asks you to read,",
        "summarise, or analyse its content.",
        "Returns the page text or raw file content as a string."
    ),
    arguments = list(
        url = ellmer::type_string(
            "The full URL to fetch, including the scheme (https:// or http://)."
        )
    )
)

# ── 4. System prompt builder ─────────────────────────────────────────────────
# All conventions and instructions live in context_text (MY_CONTEXT.txt).
# This function simply wraps that content in a confirmation header so the
# model explicitly acknowledges it has read and incorporated the context.

build_system_prompt <- function() {
    glue::glue(
        "I have read and fully incorporated the following context and instructions.
        I will apply them consistently throughout this session.

        --- CONTEXT ---
        {context_text}
        --- END CONTEXT ---",
        .trim = FALSE
    )
}


# ── 5. Chat factory ──────────────────────────────────────────────────────────
# browse_tool (defined in 3b) is registered on every new chat session so
# URL fetching is available without any extra manual step.

get_anthropic_chat <- function(model = NULL) {
    current_model <- model %||% getOption(".my_ai_model")

    chat_obj <- ellmer::chat_anthropic(
        model         = current_model,
        system_prompt = build_system_prompt()
    )

    # Attach the web-browsing tool to every session automatically
    chat_obj$register_tool(browse_tool)

    chat_obj
}

# ── 6. Model switcher ────────────────────────────────────────────────────────

switch_ai_model <- function(model_name) {
    actual_id <- if (model_name %in% names(my_models)) {
        my_models[[model_name]]
    } else {
        model_name   # assume caller passed a raw model ID
    }

    options(.my_ai_model = actual_id)
    chat <<- get_anthropic_chat(model = actual_id)

    cat(
        "✅ Model switched to:", actual_id,
        "(friendly name:", model_name, ")\n"
    )
}

# ── 7. Convenience wrappers ──────────────────────────────────────────────────

#' Opus — complex statistical reasoning & explanation
set_opus   <- function() switch_ai_model("opus")

#' Sonnet — coding, Shiny, standard analysis  (default)
set_sonnet <- function() switch_ai_model("sonnet")

#' Haiku — batch coding, simple classifications
set_haiku  <- function() switch_ai_model("haiku")

# ── 8. Session start ─────────────────────────────────────────────────────────

start_chat <- function(mode = c("ellmer", "chattr")) {
    mode <- match.arg(mode)
    chat <<- get_anthropic_chat()

    if (mode == "chattr") {
        chattr::chattr_use(chat)
        chattr::chattr_app()
    } else {
        ellmer::live_browser(chat)
    }

    invisible(chat)
}

# ── 9. Save chat ─────────────────────────────────────────────────────────────
#' Save the current global `chat` object.
#' @param file_name  Base name (no extension) for the output files.
#' @param chat_obj   Chat object to save; defaults to global `chat`.

my_save_chat <- function(file_name, chat_obj = chat) {
    path_rds <- paste0(my_chat_rds_path, "/", file_name)
    path_txt <- paste0(my_chat_txt_path, "/", file_name)

    # --- RDS: preserves the full object for later continuation ---------------
    saveRDS(chat_obj, paste0(path_rds, ".rds"))

    # --- Plain text: human-readable transcript -------------------------------
    chat_obj$get_turns() |>
        purrr::map_chr(\(t) glue::glue("[{t@role}]:\n{t@text}\n")) |>
        writeLines(paste0(path_txt, ".txt"))

    cat(
        "💾 Chat saved:\n",
        "   RDS :", paste0(path_rds, ".rds"), "\n",
        "   TXT :", paste0(path_txt, ".txt"), "\n"
    )

    invisible(chat_obj)
}

# ── 10. Restore chat ──────────────────────────────────────────────────────────
#' Restore a previously saved chat and reopen it in live_browser().
#' New turns are added to the *global* `chat` so my_save_chat() captures them.
#' @param file_name  Base name used when the chat was saved (no extension).

my_restore_chat <- function(file_name) {
    path_rds <- paste0(my_chat_rds_path, "/", file_name, ".rds")

    if (!file.exists(path_rds)) {
        stop("File not found: ", path_rds, call. = FALSE)
    }

    # <<- ensures the global `chat` is updated, not a local copy
    chat <<- readRDS(path_rds)

    cat("♻️  Chat restored from:", path_rds, "\n")
    cat("   Turns loaded:", length(chat$get_turns()), "\n")

    ellmer::live_browser(chat)

    invisible(chat)
}

