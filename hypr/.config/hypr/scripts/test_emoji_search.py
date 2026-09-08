#!/usr/bin/env python3
"""Tests for emoji_search. 'wood' must surface wood emojis, not blond-woman noise."""

from __future__ import annotations

import unittest

from emoji_search import Emoji, load_emojis, search


CATALOG = [
    Emoji("👱‍♀️", "woman: blond hair", ("blond", "hair", "woman")),
    Emoji("🪵", "wood", ("log", "lumber", "timber", "wood")),
    Emoji("🪓", "axe", ("axe", "chop", "hatchet", "split", "wood")),
    Emoji("🥘", "shallow pan of food", ("casserole", "food", "paella", "pan", "shallow")),
    Emoji("🥴", "woozy face", ("dizzy", "intoxicated", "tipsy", "woozy")),
]


class SearchTest(unittest.TestCase):
    def test_wood_shows_wood_emojis(self):
        hits = search("wood", CATALOG)
        chars = [e.char for e in hits]
        self.assertIn("🪵", chars)
        self.assertEqual(chars[0], "🪵")
        self.assertIn("🪓", chars)
        self.assertNotIn("👱‍♀️", chars)
        self.assertNotIn("🥘", chars)
        self.assertNotIn("🥴", chars)

    def test_log_alias_finds_wood(self):
        hits = search("log", CATALOG)
        self.assertEqual(hits[0].char, "🪵")

    def test_fuzzy_prefix_inside_a_word(self):
        hits = search("woo", CATALOG)
        chars = [e.char for e in hits]
        self.assertEqual(chars[0], "🪵")
        self.assertIn("🥴", chars)

    def test_empty_query_keeps_catalog_order(self):
        hits = search("", CATALOG)
        self.assertEqual([e.char for e in hits], [e.char for e in CATALOG])

    def test_one_rofi_row_per_emoji(self):
        e = Emoji(
            "😺",
            "grinning cat",
            ("cat", "face", "grinning", "mouth", "open", "smile"),
        )
        row = e.rofi_row()
        self.assertNotIn("\n", row)
        self.assertTrue(row.startswith("grinning cat") or " cat " in f" {row}")
        self.assertIn("😺", row.split("\0", 1)[0].split("\t")[-1])

    def test_cat_does_not_match_intoxicated(self):
        catalog = CATALOG + [
            Emoji("🐱", "cat face", ("cat", "face", "pet")),
            Emoji("🐈", "cat", ("cat", "pet")),
        ]
        hits = search("cat", catalog)
        chars = [e.char for e in hits]
        self.assertNotIn("🥴", chars)
        self.assertEqual(set(chars[:2]), {"🐈", "🐱"})


class RealDataTest(unittest.TestCase):
    def test_wood_shows_wood_emojis(self):
        hits = search("wood", load_emojis())
        chars = [e.char for e in hits]
        self.assertTrue(chars, "expected hits for 'wood'")
        self.assertIn("🪵", chars)
        self.assertEqual(chars[0], "🪵")

    def test_cat_shows_cats_not_woozy(self):
        hits = search("cat", load_emojis())
        chars = [e.char for e in hits]
        self.assertTrue(chars, "expected hits for 'cat'")
        self.assertNotIn("🥴", chars)
        self.assertNotIn("🪪", chars)
        self.assertTrue(any(name in "".join(e.name for e in hits[:5]) for name in ("cat",)))
        self.assertIn(chars[0], set("😺😸😹😻😼😽🙀😿😾🐱🐈") | {"🐈‍⬛"})


if __name__ == "__main__":
    unittest.main()
