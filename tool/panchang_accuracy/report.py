#!/usr/bin/env python3
"""Render a before/after Markdown table from two compare.py score files.

Usage: python report.py BEFORE.json AFTER.json
"""
import json
import sys


def main():
    before = json.load(open(sys.argv[1]))
    after = json.load(open(sys.argv[2]))
    print(f"| Check | {before['label']} | {after['label']} | Error before → after (mean / max, min) |")
    print("|---|---:|---:|---|")
    for cat, b in before["categories"].items():
        a = after["categories"].get(cat)
        if a is None:
            continue
        err = ""
        if b["mean_error_min"] is not None and a["mean_error_min"] is not None:
            err = f"{b['mean_error_min']:.2f} / {b['max_error_min']:.2f} → {a['mean_error_min']:.2f} / {a['max_error_min']:.2f}"
        print(f"| {cat} | {b['accuracy']:.2f}% | {a['accuracy']:.2f}% | {err} |")
    print(f"| **Overall (mean of categories)** | **{before['overall_category_mean']:.2f}%** | **{after['overall_category_mean']:.2f}%** | |")
    print(f"| Overall (all {after['checks']:,} checks pooled) | {before['overall_pooled']:.2f}% | {after['overall_pooled']:.2f}% | |")


if __name__ == "__main__":
    main()
