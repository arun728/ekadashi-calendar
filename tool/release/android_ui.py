#!/usr/bin/env python3
"""Print the labelled nodes of a `uiautomator dump` (stdin): bounds | label.

Disabled nodes are marked "(disabled)". Used by android-device.sh ui.
"""

import html
import re
import sys


def nodes(xml):
    found = []
    for node in re.findall(r"<node [^>]*>", xml):
        def attr(name):
            match = re.search(rf' {name}="([^"]*)"', node)
            return match.group(1) if match else ""
        label = attr("text") or attr("content-desc")
        if label:
            label = html.unescape(label).replace("\n", " / ")
            found.append((attr("bounds"), label, attr("enabled") != "false"))
    return found


if __name__ == "__main__":
    for bounds, label, enabled in nodes(sys.stdin.read()):
        print(bounds, "|", label[:120], "" if enabled else "(disabled)")
