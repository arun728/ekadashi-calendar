#!/usr/bin/env python3
"""Translate the app's English strings with Sarvam AI (docs/ROADMAP.md Phase 2).

Reads every English UI string (lib/l10n/app_en.arb plus the iOS-only and
iOS-first keys in ios_overrides.json) and asks Sarvam's /translate API for
each target language. Results go to tool/l10n/out/ for native-speaker review;
nothing in the app changes unless --apply is given.

  SARVAM_API_KEY=... python3 tool/l10n/sarvam_translate.py            # hi, ta, te
  python3 tool/l10n/sarvam_translate.py --dry-run                      # size and cost only
  SARVAM_API_KEY=... python3 tool/l10n/sarvam_translate.py --languages bn gu
  python3 tool/l10n/sarvam_translate.py --apply                        # after review

Placeholders such as {value0} and line breaks are protected. Each run
records the strings, characters, time taken and estimated cost
(Rs 20 per 10,000 characters, Sarvam's published rate) in the report.
"""
import argparse
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
from collections import OrderedDict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ARB = ROOT / "lib" / "l10n"
OVERRIDES = ROOT / "ios-native/EkadashiCore/Sources/EkadashiCore/Resources/l10n/ios_overrides.json"
OUT = ROOT / "tool" / "l10n" / "out"
API = "https://api.sarvam.ai/translate"
RUPEES_PER_CHAR = 20 / 10_000
PLACEHOLDER = re.compile(r"\{[^{}]+\}")


def load(path):
    return json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=OrderedDict)


def english_strings():
    """key -> (source file, English text)."""
    strings = OrderedDict()
    for key, value in load(ARB / "app_en.arb").items():
        if not key.startswith("@") and isinstance(value, str):
            strings[key] = ("arb", value)
    for key, value in load(OVERRIDES)["en"].items():
        strings[key] = ("ios", value)
    return strings


def protect(text):
    """Replaces placeholders and line breaks with tokens Sarvam leaves alone."""
    tokens = []

    def keep(match):
        tokens.append(match.group(0))
        return f"<{len(tokens) - 1}>"

    text = PLACEHOLDER.sub(keep, text)
    return text.split("\n"), tokens


def restore(lines, tokens):
    text = "\n".join(lines)
    for index, token in enumerate(tokens):
        text = text.replace(f"<{index}>", token)
    return text


def call(key, text, target, model, retries=4):
    body = json.dumps({"input": text, "source_language_code": "en-IN", "target_language_code": f"{target}-IN",
                       "model": model, "mode": "formal", "numerals_format": "international"}).encode()
    request = urllib.request.Request(API, data=body, method="POST",
                                     headers={"api-subscription-key": key, "Content-Type": "application/json"})
    for attempt in range(retries + 1):
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                return json.loads(response.read())["translated_text"]
        except urllib.error.HTTPError as error:
            if error.code in (429, 500, 502, 503) and attempt < retries:
                time.sleep(2 ** (attempt + 1))
                continue
            raise RuntimeError(f"Sarvam {error.code}: {error.read().decode(errors='replace')}") from error


def translate(strings, target, model, key):
    result, characters = OrderedDict(), 0
    for name, (_, english) in strings.items():
        lines, tokens = protect(english)
        out = []
        for line in lines:
            if line.strip():
                characters += len(line)
                out.append(call(key, line, target, model))
            else:
                out.append(line)
        translated = restore(out, tokens)
        if sorted(PLACEHOLDER.findall(translated)) != sorted(PLACEHOLDER.findall(english)):
            print(f"  ! {target} {name}: placeholders changed, keeping for review", file=sys.stderr)
        result[name] = translated
    return result, characters


def apply(languages):
    strings = english_strings()
    overrides = load(OVERRIDES)
    for language in languages:
        proposal = load(OUT / f"sarvam_{language}.json")["strings"]
        arb_path = ARB / f"app_{language}.arb"
        arb = load(arb_path) if arb_path.exists() else OrderedDict([("@@locale", language)])
        for key, text in proposal.items():
            source = strings.get(key, ("arb", None))[0]
            (arb if source == "arb" else overrides.setdefault(language, OrderedDict()))[key] = text
        arb_path.write_text(json.dumps(arb, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    OVERRIDES.write_text(json.dumps(overrides, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print("Applied. Regenerate the iOS strings (python3 tool/ios/generate_core_resources.py) and run the tests.")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--languages", nargs="+", default=["hi", "ta", "te"])
    parser.add_argument("--model", default="sarvam-translate:v1", choices=["sarvam-translate:v1", "mayura:v1"])
    parser.add_argument("--dry-run", action="store_true", help="count strings, characters and cost; no API calls")
    parser.add_argument("--apply", action="store_true", help="write reviewed proposals into the string tables")
    args = parser.parse_args()
    if args.apply:
        return apply(args.languages)

    strings = english_strings()
    characters = sum(len(line) for _, text in strings.values() for line in protect(text)[0] if line.strip())
    print(f"{len(strings)} strings, {characters} characters per language, "
          f"about Rs {characters * RUPEES_PER_CHAR:.0f} per language "
          f"(Rs {characters * RUPEES_PER_CHAR * len(args.languages):.0f} for {', '.join(args.languages)})")
    if args.dry_run:
        return
    key = os.environ.get("SARVAM_API_KEY")
    if not key:
        sys.exit("Set SARVAM_API_KEY (Sarvam dashboard > API keys).")
    OUT.mkdir(parents=True, exist_ok=True)
    report = ["# Sarvam translation run", "", f"Model: {args.model}", "",
              "| Language | Strings | Characters | Seconds | Estimated cost |", "| --- | --- | --- | --- | --- |"]
    for language in args.languages:
        started = time.time()
        result, sent = translate(strings, language, args.model, key)
        seconds = time.time() - started
        (OUT / f"sarvam_{language}.json").write_text(json.dumps(
            {"language": language, "model": args.model, "seconds": round(seconds, 1), "characters": sent,
             "strings": result}, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
        report.append(f"| {language} | {len(result)} | {sent} | {seconds:.0f} | Rs {sent * RUPEES_PER_CHAR:.0f} |")
        print(f"{language}: {len(result)} strings in {seconds:.0f}s")
    (OUT / "REPORT.md").write_text("\n".join(report) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
