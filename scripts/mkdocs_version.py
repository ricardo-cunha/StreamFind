"""Inject the canonical streamfind version into Markdown pages."""

from pathlib import Path
import re


_VERSION_RE = re.compile(
    r"\[workspace\.package\]\s+version\s*=\s*\"(?P<version>[^\"]+)\"",
    re.MULTILINE,
)
_TOKEN = "{{ streamfind_version }}"


def on_page_markdown(markdown, page, config, files):
    """Replace the docs version token using rust/Cargo.toml."""
    root = Path(config.config_file_path).resolve().parent
    cargo_toml = (root / "rust" / "Cargo.toml").read_text(encoding="utf-8")
    match = _VERSION_RE.search(cargo_toml)
    if match is None:
        raise RuntimeError("rust/Cargo.toml workspace package version is missing")
    return markdown.replace(_TOKEN, match.group("version"))
