# Extended audit scripts

These are development-only scripts archived from the audit, not app dependencies.
Set `PANCHANG_AUDIT_WORKDIR` (default `/workspace/panchang-audit`) and
`PANCHANG_REPO` (default `/workspace/ekadashi-calendar`). The data directory is
external because full daily exports and ephemerides are large.

Expected layout:

- `ephe/sepl_18.se1`, `ephe/semo_18.se1`, `ephe/de440s.bsp` from the primary sources linked in the report.
- `results/engine-16.json`, `engine-edges.json`: before-change Flutter exports.
- `results/engine-after-16.json`, `engine-after-edges.json`: after-change exports.
- `results/reference-16.json`, `reference-edges.json`: frozen Swiss references from `build_reference.py`.
- `results/gcal-16.json`, `gcal-edges.json`: `gcal_reference.py` output.
- `runtime/positions-extended`, `runtime/positions-lagna`, `runtime/positions-lagna-after`: compiled pure-Dart runners.
- `kotlin/*.jar`: Kotlin 2.3.20 compiler/stdlib/script-runtime, reflect 1.6.10, coroutines 1.8.0, annotations 13.0, JUnit 4.13.2, Hamcrest 1.3 and JVM org.json 20250517, downloaded from Maven Central.

For each runner, copy its `.dart.txt` file (renamed to `.dart`) together with production
`astronomy_calculator.dart`, `ephemeris_series.dart` and `lunar_series.dart`
to an isolated directory outside the Flutter project, then `dart compile exe`.
Use source commit c15bce7 for the before runner and the PR source for after.
The unchanged longitudes are audited once; ascendant geometry is audited twice.
The `benchmark_lagna.py` script subtracts mean ayanamsa to reproduce the old
production caller; `_after.py` subtracts apparent ayanamsa to reproduce the fix.
Do not compare the tropical helper alone and call it production sidereal Lagna.

Python dependencies: pyswisseph 2.10.3.2, Skyfield and NumPy, plus
`gaurabda==0.8.4` for the existing GCAL generator. Run `benchmark_positions.py`,
`benchmark_lagna.py`, `benchmark_lagna_after.py` and `review_anandadi.py` after
preparing inputs. Seeds, ranges and output names are in the scripts.

`run_kotlin_model.py` compiles the actual before/after model sources and uses
an external copy of the committed model regression with only Robolectric
runner/configuration annotations removed. It does **not** build Android
RemoteViews or prove Android integration. Gradle/SDK/device tests remain separate.

The schedule serialization comparison is between the original committed
`ekadashi_schedule_parity.json` at c15bce7 and the regenerated fixture in this PR:
match entries and occurrence IDs, then subtract each original start timestamp
from its corresponding precise timestamp. It measures lost serialization
precision, not independent astronomical accuracy.
