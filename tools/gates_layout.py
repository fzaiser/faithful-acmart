"""Cross-engine layout-geometry gates.

Tier 2 metrics (margins, line count, baseline pitch, page size), Tier 2.5 per-word
placement, and Tier 2.6 horizontal-rule weight/colour/extent."""

from __future__ import annotations

import difflib
import statistics
from pathlib import Path

import test_matrix as M
from test_matrix import TESTS
from harness import latex_pdf, typst_pdf
from pdf_extract import words, page_metrics, horizontal_rules


def _metrics_for(pdf: Path) -> dict:
    return {n: page_metrics(p) for n, p in words(pdf).items()}


def _line_pitch_drift(a: list[float], b: list[float]) -> tuple[float, int]:
    """(worst per-line pitch difference, #lines compared) for two pitch sequences.

    Returns (0.0, 0) when the sequences can't be paired one-to-one — i.e. the two
    engines broke the page into a different number of text lines, so position i in
    one isn't the same line as position i in the other. The caller then leans on
    the median-pitch gate instead.
    """
    if not a or len(a) != len(b):
        return 0.0, 0
    return max(abs(x - y) for x, y in zip(a, b)), len(a)


def gate_metrics(report: bool = False) -> list[str]:
    """Tier 2 — cross-engine layout metrics."""
    tol = M.METRICS_TOLERANCE
    failures: list[str] = []
    for name, t in TESTS.items():
        if t.kind != "twin":
            continue
        lref, tpdf = latex_pdf(name, t), typst_pdf(name)
        if not lref.exists() or not tpdf.exists():
            failures.append(f"{name}: missing PDF ({'LaTeX' if not lref.exists() else 'Typst'})")
            continue
        lm, tm = _metrics_for(lref), _metrics_for(tpdf)
        lw, tw = words(lref), words(tpdf)  # cached; carries per-page MediaBox size
        pages = [1] if t.metrics_page1_only else sorted(set(lm) & set(tm))
        gated = [("left", tol["left"], "left margin"), ("top", tol["top"], "top margin")]
        if t.metrics_uniform_pitch:
            gated.append(("pitch", tol["pitch"], "baseline pitch"))

        # Per-line pitch is gated only on single-page uniform-pitch twins. A
        # multi-page doc's page 1 is full, so acmsmall's \@textbottom rubber glue
        # stretches its paragraph gaps to the bottom margin (the documented fill we
        # can't replicate) — gating per-line spacing there would chase that drift.
        line_pitch = bool(t.metrics_uniform_pitch) and t.pages == 1
        gated_summary = "L/T"
        if t.metrics_uniform_pitch:
            gated_summary += "/pitch"
        if line_pitch:
            gated_summary += "/line-pitch"
        if report:
            print(name + ":")
        hard_failures: list[str] = []
        observed: dict[tuple[int, str], float] = {}
        compared = 0
        if not pages:
            hard_failures.append(f"{name}: no shared pages for metric comparison")
        for p in pages:
            a, b = lm.get(p), tm.get(p)
            if a is None or b is None:
                continue
            compared += 1
            lpd = _line_pitch_drift(a["pitches"], b["pitches"]) if line_pitch else None
            if report:
                lpd_s = (f"  line-pitch {lpd[0]:.2f}pt×{lpd[1]}" if lpd and lpd[1]
                         else "  line-pitch n/a (lines differ)" if line_pitch else "")
                print(f"  {name} p{p}: "
                      f"L {a['left']:.1f}/{b['left']:.1f}  R {a['right']:.1f}/{b['right']:.1f}  "
                      f"T {a['top']:.1f}/{b['top']:.1f}  "
                      f"lines {a['lines']}/{b['lines']}  pitch {a['pitch']:.2f}/{b['pitch']:.2f}"
                      f"{lpd_s}   ({gated_summary} gated; R/lines report-only)")
                continue
            for key, lim, label in gated:
                d = abs(a[key] - b[key])
                if d > lim:
                    observed[(p, key)] = d
            # Cross-engine page geometry: MediaBox width/height must agree tightly.
            lpg, tpg = lw.get(p), tw.get(p)
            if lpg and tpg:
                for dim, key in (("w", "width"), ("h", "height")):
                    d = abs(lpg[dim] - tpg[dim])
                    if d > tol[key]:
                        observed[(p, key)] = d
            # Per-line pitch: only when the line-break structure matches (aligned
            # pitch sequences); otherwise the median pitch above is the gate.
            if lpd and lpd[1] and lpd[0] > tol["line_pitch"]:
                observed[(p, "line_pitch")] = lpd[0]
        if report:
            continue
        if compared == 0:
            hard_failures.append(f"{name}: zero pages yielded comparable metric data")
        if hard_failures:
            failures.extend(hard_failures)
            continue

        allowances = M.EXPECTED_METRIC_DIFFS.get(name, ())
        allowed = {(item.page, item.key): item.max_delta for item in allowances}
        if t.expected_metrics_diff:
            missing = sorted(set(allowed) - set(observed))
            unexpected = sorted(set(observed) - set(allowed))
            excessive = sorted(
                (key, observed[key], allowed[key])
                for key in set(observed) & set(allowed)
                if observed[key] > allowed[key]
            )
            if missing or unexpected or excessive:
                failures.append(
                    f"{name}: metric residual changed ({t.expected_metrics_diff})\n"
                    f"    expected-but-passing: {missing}\n"
                    f"    unexpected failures: {[(k, round(observed[k], 2)) for k in unexpected]}\n"
                    f"    over budget: {[(k, round(got, 2), limit) for k, got, limit in excessive]}")
            else:
                print(f"diff {name} (exact expected metric keys; bounded deltas)")
        elif allowances:
            failures.append(f"{name}: metric allowances exist without expected_metrics_diff rationale")
        elif observed:
            details = []
            for (page, key), delta in sorted(observed.items()):
                limit = tol["line_pitch" if key == "line_pitch" else key]
                details.append(f"{name} p{page}: {key} Δ={delta:.2f}pt (tol {limit})")
            failures.extend(details)
        else:
            print(f"ok   {name}")
    return failures


def _align_words(lwords: list, twords: list) -> list[tuple[float, float, str]]:
    """Pair the two engines' word streams and return (dx, dy, text) per match.

    Alignment is difflib's longest-matching-block over the word TEXT (autojunk
    off, so common short words are not dropped). Only positionally-aligned
    matches are returned; words that one engine split differently (ligature or
    hyphenation segmentation) simply don't match and are ignored by construction
    — so this gate measures placement, never text coverage (the char/word bags
    own that). dy is the signed baseline difference; the caller removes the page's
    median dy so Tier 2 'top' keeps ownership of the gross first-baseline offset.
    """
    lt = [w[4] for w in lwords]
    tt = [w[4] for w in twords]
    matcher = difflib.SequenceMatcher(a=lt, b=tt, autojunk=False)
    matched: list[tuple[float, float, str]] = []
    for i1, j1, size in matcher.get_matching_blocks():
        for k in range(size):
            lw, tw = lwords[i1 + k], twords[j1 + k]
            matched.append((lw[0] - tw[0], lw[5] - tw[5], lw[4]))
    return matched


def gate_word_positions(report: bool = False) -> list[str]:
    """Tier 2.5 — per-word placement on opt-in (``word_positions``) twins.

    For each opted-in twin whose two engines break into the same lines, align the
    word streams per page and gate max |Δx0| and max |Δy−median(Δy)| (y = the
    baseline) against ``WORD_POSITION_TOLERANCE``. Subtracting the per-page median
    Δy cancels the engines' first-baseline offset (Tier 2 'top' owns that value), so
    what survives is a lost indent/centering or a single mis-spaced line."""
    tol = M.WORD_POSITION_TOLERANCE
    failures: list[str] = []
    for name, t in TESTS.items():
        if t.kind != "twin" or not t.word_positions:
            continue
        lref, tpdf = latex_pdf(name, t), typst_pdf(name)
        if not lref.exists() or not tpdf.exists():
            failures.append(f"{name}: missing PDF ({'LaTeX' if not lref.exists() else 'Typst'})")
            continue
        lw, tw = words(lref), words(tpdf)
        pages = sorted(set(lw) & set(tw))
        worst = {"dx": (0.0, ""), "dy": (0.0, "")}
        matched_total = 0
        for p in pages:
            m = _align_words(lw[p]["words"], tw[p]["words"])
            if not m:
                continue
            matched_total += len(m)
            median_dy = statistics.median(dy for _, dy, _ in m)
            for dx, dy, text in m:
                adx, ady = abs(dx), abs(dy - median_dy)
                if adx > worst["dx"][0]:
                    worst["dx"] = (adx, f"p{p} {text!r}")
                if ady > worst["dy"][0]:
                    worst["dy"] = (ady, f"p{p} {text!r}")
        if matched_total == 0:
            failures.append(f"{name}: no words aligned for the position gate")
            continue
        over = [f"{axis} Δ={delta:.2f}pt at {where} (tol {tol})"
                for axis, (delta, where) in worst.items() if delta > tol]
        if over:
            failures.append(f"{name}: word positions drifted vs LaTeX\n    " + "\n    ".join(over))
        elif report:
            print(f"ok   {name}: {matched_total} words within "
                  f"Δx {worst['dx'][0]:.2f}pt / Δy {worst['dy'][0]:.2f}pt")
    return failures
def _match_rules(lrules: list[tuple], trules: list[tuple]) -> tuple[list, list]:
    """Bijectively pair rules by colour (exact), thickness/x-mid/x-width (toleranced).
    Returns (LaTeX-only, Typst-only) rules that found no partner."""
    used = [False] * len(trules)
    unmatched_l = []
    for a in lrules:
        partner = -1
        for j, b in enumerate(trules):
            if used[j] or a[1] != b[1]:
                continue
            if (abs(a[0] - b[0]) <= M.RULE_THICKNESS_TOL
                    and abs(a[2] - b[2]) <= M.RULE_XMID_TOL
                    and abs(a[3] - b[3]) <= M.RULE_XWIDTH_TOL):
                partner = j
                break
        if partner < 0:
            unmatched_l.append(a)
        else:
            used[partner] = True
    unmatched_t = [trules[j] for j in range(len(trules)) if not used[j]]
    return unmatched_l, unmatched_t


def _fmt_rule(r: tuple) -> str:
    return f"(w={r[0]:.2f} rgb={r[1]} xmid={r[2]:.1f} xw={r[3]:.1f})"


def gate_horizontal_rules(report: bool = False) -> list[str]:
    """Tier 2.6 — horizontal-rule weight/colour/extent on opt-in (``rule_gate``)
    twins. Each LaTeX rule must find a distinct Typst rule of matching colour,
    thickness (±0.05pt), x-midpoint (±1.5pt) and x-width (±8pt), and vice versa."""
    failures: list[str] = []
    for name, t in TESTS.items():
        if t.kind != "twin" or not t.rule_gate:
            continue
        lref, tpdf = latex_pdf(name, t), typst_pdf(name)
        if not lref.exists() or not tpdf.exists():
            failures.append(f"{name}: missing PDF ({'LaTeX' if not lref.exists() else 'Typst'})")
            continue
        lrules, trules = horizontal_rules(lref), horizontal_rules(tpdf)
        total = sum(len(v) for v in lrules.values())
        if total == 0:
            failures.append(f"{name}: rule_gate is set but LaTeX draws no horizontal rules")
            continue
        local: list[str] = []
        for p in sorted(set(lrules) | set(trules)):
            miss, extra = _match_rules(lrules.get(p, []), trules.get(p, []))
            if miss or extra:
                local.append(
                    f"    p{p}: LaTeX-only {[_fmt_rule(r) for r in miss]}; "
                    f"Typst-only {[_fmt_rule(r) for r in extra]}")
        if local:
            failures.append(f"{name}: horizontal rules differ vs LaTeX\n" + "\n".join(local))
        elif report:
            print(f"ok   {name}: {total} horizontal rule(s) match")
    return failures
