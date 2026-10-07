#!/usr/bin/env python3
"""Generate lib/services/panchang/lunar_series.dart from ELP 2000-82B.

Usage: python generate_lunar_series.py ELP_DIR OUT.dart

Input: the 36 series files of ELP 2000-82B (M. Chapront-Touze & J. Chapront,
Bureau des Longitudes), CDS catalogue VI/79,
https://cdsarc.cds.unistra.fr/ftp/VI/79/. The arithmetic follows the
authors' reference routine elp82b.f (same catalogue): constants fitted to
DE200/LE200, Delaunay and planetary arguments, and the corrections of the
constants. Terms below TRUNCATION radians (and the equivalent distance) are
dropped. Each generated row is [amplitude, power of T, c0, c1, c2, c3, c4]:
term = amplitude * T^power * sin(c0 + c1 T + c2 T^2 + c3 T^3 + c4 T^4),
T in Julian centuries (TDB) from J2000; longitude/latitude amplitudes are
arcseconds and distance amplitudes kilometres.
"""
import math
import sys

TRUNCATION = 1e-7

cpi = math.pi
rad = 648000 / cpi
deg = cpi / 180
c1, c2 = 60, 3600
ath = 384747.9806743165
a0 = 384747.9806448954
am = 0.074801329518
alfa = 0.002571881335
dtasm = 2 * alfa / (3 * am)

w = [[0.0] * 6 for _ in range(4)]
eart = [0.0] * 6
peri = [0.0] * 6
w[1][1] = (218 + 18 / c1 + 59.95571 / c2) * deg
w[2][1] = (83 + 21 / c1 + 11.67475 / c2) * deg
w[3][1] = (125 + 2 / c1 + 40.39816 / c2) * deg
eart[1] = (100 + 27 / c1 + 59.22059 / c2) * deg
peri[1] = (102 + 56 / c1 + 14.42753 / c2) * deg
w[1][2], w[2][2], w[3][2] = 1732559343.73604 / rad, 14643420.2632 / rad, -6967919.3622 / rad
eart[2], peri[2] = 129597742.2758 / rad, 1161.2283 / rad
w[1][3], w[2][3], w[3][3] = -5.8883 / rad, -38.2776 / rad, 6.3622 / rad
eart[3], peri[3] = -0.0202 / rad, 0.5327 / rad
w[1][4], w[2][4], w[3][4] = 0.6604e-2 / rad, -0.45047e-1 / rad, 0.7625e-2 / rad
eart[4], peri[4] = 0.9e-5 / rad, -0.138e-3 / rad
w[1][5], w[2][5], w[3][5] = -0.3169e-4 / rad, 0.21301e-3 / rad, -0.3586e-4 / rad
eart[5], peri[5] = 0.15e-6 / rad, 0.0
preces = 5029.0966 / rad
p = [[0.0] * 3 for _ in range(9)]
p[1][1] = (252 + 15 / c1 + 3.25986 / c2) * deg
p[2][1] = (181 + 58 / c1 + 47.28305 / c2) * deg
p[3][1] = eart[1]
p[4][1] = (355 + 25 / c1 + 59.78866 / c2) * deg
p[5][1] = (34 + 21 / c1 + 5.34212 / c2) * deg
p[6][1] = (50 + 4 / c1 + 38.89694 / c2) * deg
p[7][1] = (314 + 3 / c1 + 18.01841 / c2) * deg
p[8][1] = (304 + 20 / c1 + 55.19575 / c2) * deg
p[1][2], p[2][2], p[3][2] = 538101628.68898 / rad, 210664136.43355 / rad, eart[2]
p[4][2], p[5][2], p[6][2] = 68905077.59284 / rad, 10925660.42861 / rad, 4399609.65932 / rad
p[7][2], p[8][2] = 1542481.19393 / rad, 786550.32074 / rad
delnu = 0.55604 / rad / w[1][2]
dele = 0.01789 / rad
delg = -0.08066 / rad
delnp = -0.06424 / rad / w[1][2]
delep = -0.12879 / rad
dl = [[0.0] * 6 for _ in range(5)]
for i in range(1, 6):
    dl[1][i] = w[1][i] - eart[i]
    dl[4][i] = w[1][i] - w[3][i]
    dl[3][i] = w[1][i] - w[2][i]
    dl[2][i] = eart[i] - peri[i]
dl[1][1] += cpi
zeta = [0.0, w[1][1], w[1][2] + preces]


def series(directory):
    limit = {1: TRUNCATION * rad, 2: TRUNCATION * rad, 3: TRUNCATION * ath}
    out = {1: [], 2: [], 3: []}
    for f in range(1, 37):
        iv = (f - 1) % 3 + 1
        for line in open(f"{directory}/ELP{f}").read().splitlines()[1:]:
            if not line.strip():
                continue
            if f <= 3:
                ilu = [int(line[i * 3:i * 3 + 3]) for i in range(4)]
                coef = [float(line[14:27])] + [float(line[29 + 12 * k:39 + 12 * k]) for k in range(6)]
                if abs(coef[0]) < limit[iv]:
                    continue
                tgv = coef[1] + dtasm * coef[5]
                first = coef[0] - 2 * coef[0] * delnu / 3 if f == 3 else coef[0]
                x = first + tgv * (delnp - am * delnu) + coef[2] * delg + coef[3] * dele + coef[4] * delep
                c = [sum(ilu[i] * dl[i + 1][k] for i in range(4)) for k in range(1, 6)]
                if iv == 3:
                    c[0] += cpi / 2
                out[iv].append([x, 0] + c)
            elif 4 <= f <= 9 or f >= 22:
                iz = int(line[0:3])
                ilu = [int(line[3 + i * 3:6 + i * 3]) for i in range(4)]
                pha, x = float(line[16:25]), float(line[26:35])
                if x < limit[iv]:
                    continue
                power = 1 if (7 <= f <= 9 or 25 <= f <= 27) else (2 if 34 <= f <= 36 else 0)
                c = [pha * deg, 0.0, 0.0, 0.0, 0.0]
                for k in (1, 2):
                    c[k - 1] += iz * zeta[k] + sum(ilu[i] * dl[i + 1][k] for i in range(4))
                out[iv].append([x, power] + c)
            else:
                ipla = [int(line[i * 3:i * 3 + 3]) for i in range(11)]
                pha, x = float(line[34:43]), float(line[44:53])
                if x < limit[iv]:
                    continue
                power = 1 if (13 <= f <= 15 or 19 <= f <= 21) else 0
                c = [pha * deg, 0.0, 0.0, 0.0, 0.0]
                for k in (1, 2):
                    if f < 16:
                        value = ipla[8] * dl[1][k] + ipla[9] * dl[3][k] + ipla[10] * dl[4][k]
                        value += sum(ipla[i] * p[i + 1][k] for i in range(8))
                    else:
                        value = sum(ipla[i + 7] * dl[i + 1][k] for i in range(4))
                        value += sum(ipla[i] * p[i + 1][k] for i in range(7))
                    c[k - 1] += value
                out[iv].append([x, power] + c)
    return out


def main():
    data = series(sys.argv[1])
    lines = ["// GENERATED by tool/panchang_accuracy/generate_lunar_series.py. Do not edit.",
             "//",
             "// ELP 2000-82B (Chapront-Touze & Chapront, Bureau des Longitudes;",
             "// CDS VI/79), following the authors' elp82b.f, truncated at",
             f"// {TRUNCATION:g} rad. Rows: amplitude (arcsec or km), power of T,",
             "// argument polynomial c0..c4 (radians, T in Julian centuries TDB).",
             "",
             f"const elpMeanLongitude = <double>[{', '.join(repr(w[1][k]) for k in range(1, 6))}];",
             f"const elpDistanceScale = {a0 / ath!r};",
             ""]
    for iv, name in ((1, "elpLongitude"), (2, "elpLatitude"), (3, "elpDistance")):
        lines.append(f"const {name} = <List<double>>[")
        for row in data[iv]:
            lines.append("  [" + ", ".join(repr(float(v)) for v in row) + "],")
        lines.append("];")
        lines.append("")
    open(sys.argv[2], "w").write("\n".join(lines))
    print({k: len(v) for k, v in data.items()})


if __name__ == "__main__":
    main()
