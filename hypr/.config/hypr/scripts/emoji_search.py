#!/usr/bin/env python3
"""Rank emojis for a query. Matching is word-aware: 'wood' hits wood/axe, not blond-woman."""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path

try:
    import picker as _picker

    DATA_DIR = Path(_picker.__file__).resolve().parent / "data"
except ImportError:
    DATA_DIR = Path("/usr/lib/python3.14/site-packages/picker/data")

DEFAULT_FILES = (
    "emojis_smileys_emotion",
    "emojis_people_body",
    "emojis_animals_nature",
    "emojis_food_drink",
    "emojis_activities",
    "emojis_travel_places",
    "emojis_objects",
    "emojis_symbols",
    "emojis_flags",
)

_LINE = re.compile(
    r"^(?P<char>\S+)\s+(?P<body>.+)$",
)
_SMALL = re.compile(r"<small>\((?P<aliases>[^)]*)\)</small>")
_WORDS = re.compile(r"[a-z0-9]+")
_TAGS = re.compile(r"<[^>]+>")


@dataclass(frozen=True)
class Emoji:
    char: str
    name: str
    aliases: tuple[str, ...]

    def words(self) -> tuple[str, ...]:
        parts = [_WORDS.findall(self.name.lower())]
        for alias in self.aliases:
            parts.append(_WORDS.findall(alias.lower()))
        return tuple(w for group in parts for w in group)

    def rofi_line(self) -> str:
        extra = f" ({', '.join(self.aliases)})" if self.aliases else ""
        return f"{self.char}  {self.name}{extra}"

    def rofi_row(self) -> str:
        """One row. Keywords are space-separated so rofi prefix+tokenize
        matches word starts ('cat' → 😺, not 'intoxicated')."""
        words = list(dict.fromkeys(self.words()))
        match = " ".join(words) if words else self.name
        display = f"{self.char}  {self.name}"
        return f"{match}\t{self.char}\0display\x1f{display}"


def _parse_line(line: str) -> Emoji | None:
    m = _LINE.match(line.strip())
    if not m:
        return None
    char = m.group("char")
    body = m.group("body")
    aliases: list[str] = []
    small = _SMALL.search(body)
    if small:
        aliases = [a.strip() for a in small.group("aliases").split(",") if a.strip()]
        body = _SMALL.sub("", body)
    name = _TAGS.sub("", body).strip()
    if not name:
        return None
    return Emoji(char, name, tuple(dict.fromkeys(a.lower() for a in aliases)))


def _load_file(path: Path, by_char: dict[str, Emoji]) -> None:
    if not path.is_file():
        return
    for raw in path.read_text(encoding="utf-8").splitlines():
        if not raw.strip():
            continue
        parsed = _parse_line(raw)
        if parsed is None:
            continue
        existing = by_char.get(parsed.char)
        if existing is None:
            by_char[parsed.char] = parsed
            continue
        merged = tuple(dict.fromkeys((*existing.aliases, *parsed.aliases)))
        name = existing.name if existing.name else parsed.name
        by_char[parsed.char] = Emoji(parsed.char, name, merged)


def load_emojis(data_dir: Path | None = None) -> list[Emoji]:
    root = data_dir or DATA_DIR
    by_char: dict[str, Emoji] = {}
    for stem in DEFAULT_FILES:
        _load_file(root / f"{stem}.csv", by_char)
        _load_file(root / "additional" / f"{stem}.csv", by_char)
    return list(by_char.values())


def _fuzzy_prefix_score(token: str, word: str) -> int | None:
    """Prefix with at most one gap. 3-letter queries stay exact/prefix-only.

    'wod' hits 'wood'; 'cat' does not hit 'intoxicated' or 'coat'.
    """
    if len(token) < 4:
        return None
    qi = 0
    run = 0
    best_run = 0
    for ch in word:
        if qi < len(token) and ch == token[qi]:
            run += 1
            if run > best_run:
                best_run = run
            qi += 1
        else:
            run = 0
        if qi == 0:
            return None
    if qi != len(token) or best_run < len(token) - 1:
        return None
    return 25 + best_run


def _token_score(token: str, word: str) -> int | None:
    if token == word:
        return 100
    if word.startswith(token):
        return 80 - min(len(word) - len(token), 20)
    return _fuzzy_prefix_score(token, word)


def _query_score(query: str, emoji: Emoji) -> int | None:
    tokens = _WORDS.findall(query.lower())
    if not tokens:
        return 0
    words = emoji.words()
    if not words:
        return None
    name_words = set(_WORDS.findall(emoji.name.lower()))
    total = 0
    for token in tokens:
        best: int | None = None
        best_word = ""
        for word in words:
            scored = _token_score(token, word)
            if scored is None:
                continue
            if best is None or scored > best:
                best = scored
                best_word = word
        if best is None:
            return None
        if best_word in name_words:
            best += 15
        if token == emoji.name.lower():
            best += 20
        total += best
    return total


def search(query: str, emojis: list[Emoji]) -> list[Emoji]:
    q = query.strip()
    if not q:
        return list(emojis)
    ranked: list[tuple[int, int, Emoji]] = []
    for i, emoji in enumerate(emojis):
        scored = _query_score(q, emoji)
        if scored is None:
            continue
        ranked.append((scored, -i, emoji))
    ranked.sort(key=lambda row: (row[0], row[1]), reverse=True)
    return [row[2] for row in ranked]


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Search or dump emojis for the picker.")
    parser.add_argument("query", nargs="?", default="", help="filter query")
    parser.add_argument(
        "--rofi",
        action="store_true",
        help="print rofi dmenu rows (all rows if query is empty)",
    )
    args = parser.parse_args(argv)
    emojis = load_emojis()
    if args.query:
        emojis = search(args.query, emojis)
    for emoji in emojis:
        if args.rofi:
            sys.stdout.write(emoji.rofi_row() + "\n")
        else:
            sys.stdout.write(f"{emoji.char}\t{emoji.name}\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
