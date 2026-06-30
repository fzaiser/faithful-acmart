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

#import "/src/parts/tex.typ": purify, change-case

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
