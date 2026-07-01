// Direct unit tests for the TeX-string semantics module (src/parts/tex.typ).
//
// These run WITHOUT the LaTeX/pdftotext harness: the file compiles, and a failing
// #assert.eq aborts the Typst compile. Run standalone
//   tools/tc compile tests/unit/tex.typ /dev/null
// or via the harness as the "unit" tier (tools/test.py unit / test.py check).
//
// `purify` and `change-case` are exact ports of BibTeX's purify$ / change.case$.
// Every expected value below is the LITERAL output of the real bibtex binary on
// the same input (a .bst that calls purify$ / change.case$ and write$s the
// result) — so this is an oracle test against a closed, finite spec, not against
// our own assumptions.

#import "/src/parts/tex.typ": purify, change-case, tex-to-string, tex-to-content

#let chk(fn, args, want) = assert.eq(fn, want,
  message: args + "\n  got:  " + repr(fn) + "\n  want: " + repr(want))

// ---- purify$ --------------------------------------------------------------
#chk(purify("Hello World"),          "purify Hello World",          "Hello World")
#chk(purify("\\lambda-calculus"),    "purify \\lambda-calculus",    "lambda calculus")
#chk(purify("$x^2 + \\alpha_i$"),    "purify $x^2 + \\alpha_i$",    "x2  alphai")  // math is invisible
#chk(purify("S{\\o}rensen"),         "purify S{\\o}rensen",         "Sorensen")
#chk(purify("{\\relax Ch}ristopher"), "purify {\\relax Ch}ristopher", "Christopher")
#chk(purify("{\\lambda}-calc"),      "purify {\\lambda}-calc",      " calc")  // unknown cs dropped
#chk(purify("{\\ss}{\\oe}{\\aa}"),   "purify {\\ss}{\\oe}{\\aa}",   "ssoea")  // \ss->ss \oe->oe \aa->a
#chk(purify("{\\o foo}"),            "purify {\\o foo}",            "ofoo")   // ws dropped in special char
#chk(purify("{ACM} Press"),          "purify {ACM} Press",          "ACM Press")
#chk(purify("Foo~Bar-Baz"),          "purify Foo~Bar-Baz",          "Foo Bar Baz")  // tie & hyphen -> space
#chk(purify(""),                     "purify empty",                "")

// ---- change.case$ ---------------------------------------------------------
#chk(change-case("The Foo Of Bar", "t"), "change-case t",  "The foo of bar")
#chk(change-case("The Foo Of Bar", "l"), "change-case l",  "the foo of bar")
#chk(change-case("The Foo Of Bar", "u"), "change-case u",  "THE FOO OF BAR")
#chk(change-case("FOO: The BAR baz", "t"), "change-case t colon", "Foo: The bar baz")
#chk(change-case("the {ACM} {SIG}", "t"), "change-case t braces", "the {ACM} {SIG}")
#chk(change-case("a {\\OE}uvre and {\\AA}ngstr", "t"), "change-case t foreign", "a {\\oe}uvre and {\\aa}ngstr")
#chk(change-case("title with {Nested {deep}}", "t"), "change-case t nested", "title with {Nested {deep}}")
#chk(change-case("Research Note", "t"), "change-case t simple", "Research note")

// ---- tex-to-string (raw TeX -> plain string: tokenizer + string evaluator) -
// Exact output (accents compose as combining sequences, which the text gate's
// NFKC folds; here we pin the literal codepoints).
#chk(tex-to-string("h\\'el\\`ene"),   "accents h'el`ene",  "he\u{0301}le\u{0300}ne")
#chk(tex-to-string("P\\'erez {ACM}"), "accent + braces",   "Pe\u{0301}rez ACM")
#chk(tex-to-string("{\\oe}uvre"),      "special letter oe", "œuvre")
#chk(tex-to-string("Stra\\ss e"),      "special letter ss + swallowed space", "Straße")
#chk(tex-to-string("\\AA ngstr\\\"om"),"AA + accent",       "Ångstro\u{0308}m")
#chk(tex-to-string("a--b---c and ``q'' `r'"), "input ligatures",
  "a\u{2013}b\u{2014}c and \u{201C}q\u{201D} \u{2018}r\u{2019}")
#chk(tex-to-string("Vol.~5"),          "tie -> nbsp",       "Vol.\u{00A0}5")
#chk(tex-to-string("10\\,000 \\& 5\\%"), "thin space + escapes", "10\u{2009}000 & 5%")
#chk(tex-to-string("a \\textsc{x} \\texttt{y} \\textbf{z} \\emph{w}"),
  "formatting dropped to text", "a x y z w")
#chk(tex-to-string("\\noopsort{aaa}Smith"), "noopsort discarded", "Smith")

// ---- tex-to-content (tokenizer + content evaluator): structural checks -----
// (content equality carries empty-sequence wrappers; assert the element kind via
// repr instead.) Each names the Typst element the command must produce.
#let has(s, sub) = assert(repr(tex-to-content(s)).contains(sub),
  message: "tex-to-content(" + repr(s) + ") should contain a " + sub + " element\n  got: " + repr(tex-to-content(s)))
#has("x \\textbf{y}", "strong")
#has("a \\emph{b}", "emph")
#has("\\textit{b}", "styled")
#has("\\textsl{b}", "styled")
#has("\\textsc{acm}", "smallcaps")
#has("\\underline{u}", "underline")
#has("x\\textsuperscript{2}", "super")
#has("see \\url{http://a.b}", "link")
#has("ref \\href{http://a.b}{text}", "link")
#has("math $\\frac{n}{2} \\leq x^{2n}$", "equation")  // real Typst math

// Multi-letter math runs: Typst reads `ab` as ONE (undefined) identifier and
// errors, so the math evaluator must split a run into separate atoms. These would
// panic ("unknown variable: ab" / "x2") if the run were emitted whole; reaching
// the asserts proves it doesn't, and the atoms stay separate.
#has("$ab$", "[a]")
#has("$ab$", "[b]")
#has("$x_{ab}$", "attach")        // multi-letter subscript, was a crash
#has("$x2$", "equation")          // letter+digit run, was "unknown variable: x2"
// \ensuremath switches to math (was routed to text mode -> \alpha panicked).
#has("\\ensuremath{\\alpha}", "equation")

// Declaration *switches* restyle the REST of the group, not just the next char:
// `{\it a b}` -> italic over the whole "a b" (the old arg-grab gave italic over
// "a" only). `[a b]` as one leaf inside the styled content is the discriminator.
#has("{\\it a b} c", "styled")
#has("{\\it a b} c", "[a b]")
#has("x {\\bf y z}", "strong")
#has("{\\sc a b}", "smallcaps")
#chk(tex-to-string("{\\it a b} c"), "switch drops formatting in string mode", "a b c")
// ...but \textit/\textbf are argument-takers: only the braced group is styled.
#chk(tex-to-string("\\textit{a} b"), "arg-form styles only its argument", "a b")

// Robustness (compile-only): these must not crash the generated math source.
//   - \text{..} with an embedded " and \ (must be escaped, not injected)
//   - the math spacing control symbols \, \: \; \! \(space) and ~
#let _esc = tex-to-content("$\\text{a\"b\\c} + 1$")
#let _spc = tex-to-content("$a\\,b\\;c\\!d\\:e\\ f~g$")

// regression: an accent grabbing the LAST char of a run (run = 1 cluster) — the
// tail `().join("")` is `none`, which once built a `value: none` text token.
#chk(tex-to-string("Caf\\'e"), "accent at end of field", "Cafe\u{0301}")
#chk(tex-to-string("a\\'e"),   "accent on lone trailing char", "ae\u{0301}")

// regression: the linear token walk is a LOOP, so a field with FAR more tokens
// than Typst's ~72 call-depth limit must not stack-overflow. These would error
// ("maximum function call depth exceeded") under the old head+recurse walk — the
// unit gate compiles this file, so reaching here at all is the assertion.
#let _stress300 = "x" + ("\\'e" * 300)                 // ~300 accent tokens (text)
#let _stressmath = "$" + ("a_1 + " * 200) + "b$"        // ~600 math tokens
#assert(repr(tex-to-content(_stress300)).len() > 0)
#assert(repr(tex-to-content(_stressmath)).contains("equation"))
