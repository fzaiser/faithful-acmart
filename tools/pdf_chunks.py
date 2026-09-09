"""Compare reading order within tagged Typst chunks against the untagged LaTeX text stream.

Chunks are checked independently: footnotes and floats can appear in different positions in the two extraction orders."""

from __future__ import annotations

import re
import sys
from collections import Counter
from pathlib import Path

from pdf_extract import pdf_text
from pdf_text_tokens import tokenize


def load_tounicode(font) -> dict:
    """Return the font CMap's {byte code: Unicode text} mapping."""
    import pikepdf
    m: dict = {}
    tu = font.get("/ToUnicode")
    if tu is None:
        return m
    data = tu.read_bytes().decode("latin1")
    hx = bytes.fromhex
    for b in re.findall(r"beginbfchar(.*?)endbfchar", data, re.S):
        for src, dst in re.findall(r"<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>", b):
            m[int(src, 16)] = hx(dst).decode("utf-16-be", "replace")
    for b in re.findall(r"beginbfrange(.*?)endbfrange", data, re.S):
        for lo, hi, dst in re.findall(
            r"<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>", b
        ):
            base = hx(dst).decode("utf-16-be", "replace")
            for i, code in enumerate(range(int(lo, 16), int(hi, 16) + 1)):
                m[code] = chr(ord(base[0]) + i) if base else ""
    return m


def _page_mcid_text(page) -> dict:
    """Return {MCID: decoded text} for a page."""
    import pikepdf
    fonts: dict = {}
    res = page.get("/Resources", {})
    fdict = res.get("/Font", {}) if res else {}
    for fn in fdict:
        fonts[str(fn)] = load_tounicode(fdict[fn])
    out: dict = {}
    cur_mcid = None
    stack: list = []
    curfont = None
    for instr in pikepdf.parse_content_stream(page):
        op, ops = str(instr.operator), instr.operands
        if op == "BDC" and len(ops) >= 2 and isinstance(ops[1], pikepdf.Dictionary) and "/MCID" in ops[1]:
            cur_mcid = int(ops[1]["/MCID"])
            stack.append(cur_mcid)
        elif op in ("BDC", "BMC"):
            stack.append(cur_mcid)
        elif op == "EMC":
            if stack:
                stack.pop()
            cur_mcid = stack[-1] if stack else None
        elif op == "Tf":
            curfont = str(ops[0])
        elif op in ("Tj", "TJ", "'", '"') and cur_mcid is not None:
            tomap = fonts.get(curfont, {})
            chunks = ops[0] if op == "TJ" else [ops[0]]
            s = ""
            for c in chunks:
                if not isinstance(c, pikepdf.String):
                    continue
                raw = bytes(c)
                for i in range(0, len(raw) - 1, 2):  # Two-byte CID codes.
                    s += tomap.get(raw[i] << 8 | raw[i + 1], "")
            out[cur_mcid] = out.get(cur_mcid, "") + s
    return out


# Relocated blocks need separate chunks to preserve their parent's reading order.
_BLOCK_BREAK = {"Note", "Caption", "Figure", "Table", "Formula"}

# Generated labels can join neighboring words in flat extraction; exclude them from order matching.
_DROP = {"Lbl"}

_HEADING = {"H", "H1", "H2", "H3", "H4", "H5", "H6"}
_NUMBERING = re.compile(r"^\d+(\.\d+)*$")


def _strip_generated_heading_number(role: str, toks: list[str]) -> list[str]:
    if role.strip() not in _HEADING or not toks:
        return toks
    i = 0
    while i < len(toks) and _NUMBERING.fullmatch(re.sub(r"\s+", "", toks[i])):
        i += 1
    return toks[i:] if i else toks


def _role(elem) -> str:
    s = elem.get("/S")
    return str(s)[1:] if s is not None else "?"


def _flatten(elem, mcid_text, pdf, pi_default) -> str:
    """Merge inline descendants in place, leaving relocated block content for separate chunks."""
    import pikepdf
    pg = elem.get("/Pg")
    pi = pi_default
    if pg is not None:
        pi = _index_of_page(pdf, pg)
    k = elem.get("/K")
    items = k if isinstance(k, pikepdf.Array) else ([k] if k is not None else [])
    parts: list[str] = []
    for it in items:
        if isinstance(it, int):
            parts.append(mcid_text.get(pi, {}).get(it, ""))
        elif isinstance(it, pikepdf.Dictionary) and it.get("/Type") == pikepdf.Name("/MCR"):
            mp = _index_of_page(pdf, it["/Pg"]) if it.get("/Pg") else pi
            parts.append(mcid_text.get(mp, {}).get(int(it["/MCID"]), ""))
        elif (isinstance(it, pikepdf.Dictionary) and "/S" in it
              and _role(it) not in _BLOCK_BREAK and _role(it) not in _DROP):
            # Separate child elements at word boundaries, but retain raw MCID joins within hyphenated words.
            parts.append(" " + _flatten(it, mcid_text, pdf, pi) + " ")
    return "".join(parts)


def _block_break_descendants(elem):
    import pikepdf
    k = elem.get("/K")
    items = k if isinstance(k, pikepdf.Array) else ([k] if k is not None else [])
    for it in items:
        if isinstance(it, pikepdf.Dictionary) and "/S" in it:
            if _role(it) in _BLOCK_BREAK:
                yield it
            else:
                yield from _block_break_descendants(it)


def _has_direct_text(elem) -> bool:
    import pikepdf
    k = elem.get("/K")
    items = k if isinstance(k, pikepdf.Array) else ([k] if k is not None else [])
    for it in items:
        if isinstance(it, int):
            return True
        if isinstance(it, pikepdf.Dictionary) and it.get("/Type") == pikepdf.Name("/MCR"):
            return True
    return False


def _index_of_page(pdf, pg) -> int:
    for i, p in enumerate(pdf.pages):
        if p.objgen == pg.objgen:
            return i
    return 0


def typst_chunks(pdf_path: Path) -> list[tuple[str, list[str]]]:
    """Return (role, tokens) chunks in tag-tree order, merging each text-bearing element with its inline descendants."""
    import pikepdf
    pdf = pikepdf.Pdf.open(str(pdf_path))
    root = pdf.Root.get("/StructTreeRoot")
    if root is None:
        return []
    mcid_text = {i: _page_mcid_text(p) for i, p in enumerate(pdf.pages)}

    chunks: list[tuple[str, list[str]]] = []

    def visit(elem):
        role = _role(elem)
        if _has_direct_text(elem):
            toks = tokenize(_flatten(elem, mcid_text, pdf, _page_index(pdf, elem)))
            toks = _strip_generated_heading_number(role, toks)
            if toks:
                chunks.append((role, toks))
            for bb in _block_break_descendants(elem):
                visit(bb)
            return
        k = elem.get("/K")
        items = k if isinstance(k, pikepdf.Array) else ([k] if k is not None else [])
        for it in items:
            if isinstance(it, pikepdf.Dictionary) and "/S" in it:
                visit(it)

    top = root["/K"]
    visit(top if isinstance(top, pikepdf.Dictionary) else root)
    return chunks


def _page_index(pdf, elem) -> int:
    pg = elem.get("/Pg")
    return _index_of_page(pdf, pg) if pg is not None else 0


def latex_stream(pdf_path: Path) -> list[str]:
    return tokenize(pdf_text(pdf_path))


def _lcs_len(a: list[str], b: list[str]) -> int:
    """Longest common subsequence length; repeated words can match without cascading position errors."""
    if not a or not b:
        return 0
    prev = [0] * (len(b) + 1)
    for x in a:
        cur = [0] * (len(b) + 1)
        for j, y in enumerate(b, 1):
            cur[j] = prev[j - 1] + 1 if x == y else max(prev[j], cur[j - 1])
        prev = cur
    return prev[-1]


def _locate_window(chunk: list[str], pos: dict, n_stream: int) -> tuple[int, int]:
    """Locate a chunk using the densest cluster of anchor-token offsets.

    Local matching prevents repeated words elsewhere in the document from creating false disorder."""
    present = [(i, t) for i, t in enumerate(chunk) if t in pos and len(pos[t]) <= 20]
    if not present:
        return 0, n_stream - 1
    origins = sorted(sp - ci for ci, t in present for sp in pos[t])
    tol = 4
    best_o, best_n, lo = origins[0], 0, 0
    for hi in range(len(origins)):
        while origins[hi] - origins[lo] > tol:
            lo += 1
        if hi - lo + 1 > best_n:
            best_n, best_o = hi - lo + 1, origins[lo]
    slack = 8
    return (max(0, best_o - slack),
            min(n_stream - 1, best_o + len(chunk) + slack))


def _reconcile_boundaries(chunk: list[str], window: list[str]) -> list[str]:
    """Join or split chunk tokens to match consecutive stream tokens before alignment.

    Tagged runs can omit spaces at line breaks or split words across elements."""
    vocab = set(window)
    remaining = Counter(window)
    by_len = sorted(vocab, key=len, reverse=True)
    out: list[str] = []
    i = 0
    def consume(toks: list[str]) -> None:
        for tok in toks:
            if remaining[tok] > 0:
                remaining[tok] -= 1

    while i < len(chunk):
        merged = None
        acc = ""
        for j in range(i, min(len(chunk), i + 8)):
            acc += chunk[j]
            parts = chunk[i:j + 1]
            needs_merge = any(t not in vocab for t in parts)
            needs_merge = needs_merge or any(Counter(parts)[t] > remaining[t] for t in set(parts))
            if j > i and acc in vocab and needs_merge:
                merged = (acc, j + 1)
        if merged is not None:
            out.append(merged[0])
            consume([merged[0]])
            i = merged[1]
            continue

        t = chunk[i]
        if t in vocab:
            out.append(t)
            consume([t])
            i += 1
            continue
        pieces, rest = [], t
        while rest:
            m = next((w for w in by_len if rest.startswith(w)), None)
            if m is None or len(pieces) >= 8:
                pieces = None
                break
            pieces.append(m)
            rest = rest[len(m):]
        added = pieces if pieces and len(pieces) > 1 else [t]
        out.extend(added)
        consume(added)
        i += 1
    return out


def chunk_order(chunk: list[str], stream: list[str]) -> dict:
    """Align a localized chunk with the flat stream.

    disorder counts present tokens dropped to preserve order; missing counts tokens absent from the window.
    norm is disorder divided by the number of present tokens."""
    fullpos: dict = {}
    for i, t in enumerate(stream):
        fullpos.setdefault(t, []).append(i)
    lo, hi = _locate_window(chunk, fullpos, len(stream))
    def score(window: list[str], span: tuple[int, int]) -> dict:
        tokens = _reconcile_boundaries(chunk, window)
        avail: Counter = Counter(window)
        present: list[str] = []
        missing: list[str] = []
        for t in tokens:
            if avail[t] > 0:
                present.append(t); avail[t] -= 1
            else:
                missing.append(t)
        disorder = len(present) - _lcs_len(present, window)
        norm = disorder / len(present) if present else 0.0
        return {"disorder": disorder, "present": len(present), "norm": norm,
                "missing": missing, "window": span}

    local = score(stream[lo:hi + 1], (lo, hi))
    if local["disorder"] and local["missing"]:
        wide = score(stream, (0, len(stream) - 1))
        if wide["disorder"] < local["disorder"]:
            return wide
    return local


def _main(argv: list[str]) -> int:
    root = Path(__file__).resolve().parent.parent
    if not argv:
        print("usage: pdf_chunks.py <stem> [--tokens]   (e.g. title-test)")
        return 2
    stem = argv[0]
    show_tokens = "--tokens" in argv
    tpdf = root / "tests/out/typst" / f"{stem}.pdf"
    lpdf = root / "tests/out/latex" / f"{stem}.pdf"
    if not tpdf.exists():
        print(f"missing {tpdf}")
        return 1
    chunks = typst_chunks(tpdf)
    stream = latex_stream(lpdf) if lpdf.exists() else None
    print(f"{stem}: {len(chunks)} chunks"
          + ("" if stream else "  (no LaTeX twin — order check skipped)"))
    for role, toks in chunks:
        head = " ".join(toks)
        if len(head) > 90:
            head = head[:87] + "..."
        line = f"  <{role}> {head!r}"
        if stream is not None:
            r = chunk_order(toks, stream)
            flag = "  ⚠ ORDER" if r["disorder"] else ""
            miss = f"  missing={r['missing']}" if r["missing"] else ""
            line += f"\n        disorder={r['disorder']} present={r['present']}" \
                    f" norm={r['norm']:.3f}{flag}{miss}"
        print(line)
        if show_tokens:
            print(f"        tokens={toks}")
    return 0


if __name__ == "__main__":
    raise SystemExit(_main(sys.argv[1:]))
