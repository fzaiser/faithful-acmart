"""Structure-aware text extraction + intra-chunk order check.

The two engines are asymmetric and we lean into it: Typst PDFs are *tagged*, so
their structure tree gives logical chunks (the title, each author line, the
contact-info block, the CCS list, ...) with their tokens in *logical* reading
order. LaTeX references are *flat* (untagged) — pdftotext gives only a single
physical-reading-order token stream.

So this is a TREE-vs-FLAT comparison. We don't need LaTeX to be tagged: the Typst
tree tells us what the logical groups are and what order their tokens belong in;
the flat LaTeX stream only has to *contain* those tokens in a consistent order,
and order is a 1-D property a flat stream is enough to verify against.

Two things the global word/char bags (tools/test.py) can't see, but this can:
  * a chunk's tokens going missing/appearing, *localized* to that chunk; and
  * a chunk's elements emitted in the WRONG order (affiliation<->email swap,
    reordered citation fields, flipped author order) — caught as LCS disorder
    against the flat stream.

Crucially, INTER-chunk order is NOT checked: Typst emits footnote/contact chunks
first in the tree even though they render at the page bottom, so tag-tree order
disagrees with pdftotext reading order by design. Only the order WITHIN each
chunk is gated; the chunk is matched as a sub-sequence of the stream, so other
content may interpose between its tokens (robust to reflow, unlike bigrams).

Tokenization is shared with tools/test.py's word bag via pdf_text_tokens.py, so
chunk tokens and global text tokens always agree on URL, symbol, dash, and PDF
extraction cleanup.
"""

from __future__ import annotations

import re
import subprocess
import sys
from collections import Counter
from pathlib import Path

from pdf_text_tokens import tokenize


# --- Typst side: decode the tagged structure tree --------------------------
def load_tounicode(font) -> dict:
    """{byte-code -> unicode-str} from a font's /ToUnicode CMap (bf char/range)."""
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
    """{MCID -> decoded text} for one page, parsing its content stream + ToUnicode."""
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
                for i in range(0, len(raw) - 1, 2):     # 2-byte CID codes
                    s += tomap.get(raw[i] << 8 | raw[i + 1], "")
            out[cur_mcid] = out.get(cur_mcid, "") + s
    return out


# Block-level roles that are their own logical chunk even when nested inside a
# text-bearing element, because they are physically RELOCATED away from it: a
# footnote (Note) renders at the page bottom, a caption beside its float. Merged
# into the parent they would scramble the parent's reading order against the flat
# stream. Everything else (Strong/Em/Link/Span/Lbl/Code-inline/...) is inline and
# merges into its parent chunk.
_BLOCK_BREAK = {"Note", "Caption", "Figure", "Table", "Formula"}

# Generated marker labels (footnote/endnote marks, list bullets/numbers) — like a
# heading number or page folio, layout not content, and extracted inconsistently:
# the rendered superscript mark has no space before it, so pdftotext glues it to
# the preceding word ("footnote1") while the structure tree keeps it a separate
# Lbl element. Dropped from chunk text so that asymmetry isn't read as disorder.
_DROP = {"Lbl"}

# Auto-generated heading numbering ("1", "2.3") — a layout label, not content,
# that pdftotext extracts in an unstable position (like a page folio); stripped
# from heading chunks so the order check sees only the title words.
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
    """In-order text of a structure element's subtree, so inline children
    (Strong/Em/Link/Span) merge at the position they actually occur — preserving
    the chunk's reading order (the naive 'texts then children' walk loses it).
    Block-break children (footnotes, captions) are skipped: they're relocated and
    emitted as their own chunks by ``typst_chunks``."""
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
            # Pad a child element with spaces: it abuts sibling text at a word
            # boundary whose rendered space sits outside both marked-content runs
            # ("ACM Reference Format:" + "Ben Trovato" -> "Format:Ben" without it).
            # MCID runs (the int/MCR branches above) are joined RAW, because a
            # word hyphenated at a line break splits across two MCIDs of the same
            # element ("amplifi-" + "carique") and must stay one token to rejoin.
            parts.append(" " + _flatten(it, mcid_text, pdf, pi) + " ")
    return "".join(parts)


def _block_break_descendants(elem):
    """Yield block-break elements nested anywhere under a text-bearing element, so
    they become their own chunks instead of being swallowed by the parent."""
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
    """True if the element owns text (MCID/MCR in its K), vs. a pure container."""
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
    """Logical chunks of a tagged Typst PDF, in tag-tree order.

    A chunk is the smallest text-bearing structure element (one that owns MCID
    text); pure containers (Document/Sect/Div with only child elements) are
    recursed into, so each leaf P/Span/Hn/TD/Caption becomes its own chunk with
    its inline descendants merged in reading order. Returns [(role, tokens)].
    """
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
            for bb in _block_break_descendants(elem):   # relocated footnotes etc.
                visit(bb)
            return                      # inline descendants already merged in
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


# --- LaTeX side: flat reading-order token stream ---------------------------
def latex_stream(pdf_path: Path) -> list[str]:
    out = subprocess.run(
        ["pdftotext", str(pdf_path), "-"], capture_output=True, text=True
    ).stdout
    return tokenize(out)


# --- intra-chunk order check (LCS alignment) -------------------------------
def _lcs_len(a: list[str], b: list[str]) -> int:
    """Length of the longest common subsequence of two token lists (rolling DP).

    LCS, not Kendall-tau-on-positions, is what makes the order check robust: it
    finds the OPTIMAL monotone matching, so a repeated common word ("the", "of")
    or a single missing/extra token can't cascade into spurious disorder the way
    k-th-occurrence position matching does. A genuine reorder (an affiliation/
    email swap, a flipped citation field) still forces dropping the smaller of
    the two swapped groups, so it surfaces as disorder; in-order prose scores 0.
    """
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
    """Stream span holding the chunk's region, sized to the chunk and centred where
    it actually maps. A logical chunk is laid out contiguously in LaTeX too
    (interposition happens BETWEEN chunks — footnotes, columns — not within), so
    localizing here is what stops common words ("the", "of", repeated names) from
    matching far-away duplicates and manufacturing disorder.

    The offset of the chunk within the stream is estimated from its anchor tokens:
    each anchor at chunk index ``ci`` occurring at stream position ``sp`` implies a
    region origin ``sp - ci``. A correctly aligned chunk has ALL its anchors agree
    on one origin (within a little slack for interposed tokens), so the right origin
    is the one where the most anchor occurrences CLUSTER — not the median, which a
    token duplicated in another chunk (an author name reused in the contact line) or
    a paragraph reused verbatim drags away from the true cluster. Voting for the
    densest cluster also makes a reused paragraph self-correct: its copies form
    several equal clusters, any of which is an in-order match. The window is the
    chunk-length span from that origin plus slack, fixed to the chunk so it never
    reaches into neighbouring paragraphs.
    """
    present = [(i, t) for i, t in enumerate(chunk) if t in pos and len(pos[t]) <= 20]
    if not present:
        return 0, n_stream - 1
    origins = sorted(sp - ci for ci, t in present for sp in pos[t])
    # Densest cluster: slide a small window over the sorted origins and take the
    # span holding the most (ties -> earliest, which an in-order copy satisfies).
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
    """Split a chunk token the structure tree glued across a line break back into
    the stream's tokenization, so the boundary disagreement doesn't hide content
    from the order check.

    Word boundaries are unrecoverable from the tag tree: a line break renders no
    space and drops the hyphenation hyphen, so consecutive marked-content runs
    abut ("Group"+"Hekla" -> "GroupHekla", "USA"+email -> "USAemail"). pdftotext
    splits them. A chunk token that is ABSENT from the window but equals a
    concatenation of consecutive window tokens (greedy longest-prefix over the
    window vocabulary) is replaced by those tokens. This is the "sub-token prefix"
    rule, done at word granularity — so unlike a char-level match it neither
    re-flags content reorders the bags already own nor reacts to a single stray
    char. Its payoff: an email glued onto an affiliation line is un-glued, so its
    ORDER is actually checked (the conference author grid, otherwise a blind spot).
    """
    vocab = set(window)
    by_len = sorted(vocab, key=len, reverse=True)   # longest-prefix first
    out: list[str] = []
    for t in chunk:
        if t in vocab:
            out.append(t)
            continue
        pieces, rest = [], t
        while rest:
            m = next((w for w in by_len if rest.startswith(w)), None)
            if m is None or len(pieces) >= 8:
                pieces = None
                break
            pieces.append(m)
            rest = rest[len(m):]
        out.extend(pieces if pieces and len(pieces) > 1 else [t])
    return out


def chunk_order(chunk: list[str], stream: list[str]) -> dict:
    """Project a chunk's ordered tokens onto the flat stream and measure order.

    The chunk is first localized to its region of the stream (``_locate_window``);
    glued tokens are then reconciled to the window's tokenization
    (``_reconcile_boundaries``) and the result aligned to the window by LCS.
    ``disorder`` is the number of present chunk tokens that LCS had to drop to keep
    the match monotone — i.e. tokens that appear out of order relative to the
    stream; 0 means the chunk's tokens occur in the stream in the chunk's own order
    (other content may interpose). Tokens absent from the window are reported as
    ``missing`` (a content gap, or an extraction artifact) and excluded from the
    order measure. ``norm`` is disorder / present in [0,1].
    """
    fullpos: dict = {}
    for i, t in enumerate(stream):
        fullpos.setdefault(t, []).append(i)
    lo, hi = _locate_window(chunk, fullpos, len(stream))
    window = stream[lo:hi + 1]
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
            "missing": missing, "window": (lo, hi)}


# --- CLI: inspect chunks + order vs the LaTeX twin -------------------------
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
