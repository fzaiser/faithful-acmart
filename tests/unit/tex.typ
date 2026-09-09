// Expected purify$ and change.case$ values come from the BibTeX binary.

#import "/src/parts/tex.typ": purify, change-case, tex-to-string, tex-to-content, script-size
#import "/src/formats/_base.typ": tp

#let chk(fn, args, want) = assert.eq(fn, want,
  message: args + "\n  got:  " + repr(fn) + "\n  want: " + repr(want))

#chk(purify("Hello World"),          "purify Hello World",          "Hello World")
#chk(purify("\\lambda-calculus"),    "purify \\lambda-calculus",    "lambda calculus")
#chk(purify("$x^2 + \\alpha_i$"),    "purify $x^2 + \\alpha_i$",    "x2  alphai")
#chk(purify("S{\\o}rensen"),         "purify S{\\o}rensen",         "Sorensen")
#chk(purify("{\\relax Ch}ristopher"), "purify {\\relax Ch}ristopher", "Christopher")
#chk(purify("{\\lambda}-calc"),      "purify {\\lambda}-calc",      " calc")
#chk(purify("{\\ss}{\\oe}{\\aa}"),   "purify {\\ss}{\\oe}{\\aa}",   "ssoea")
#chk(purify("{\\o foo}"),            "purify {\\o foo}",            "ofoo")
#chk(purify("{ACM} Press"),          "purify {ACM} Press",          "ACM Press")
#chk(purify("Foo~Bar-Baz"),          "purify Foo~Bar-Baz",          "Foo Bar Baz")
#chk(purify(""),                     "purify empty",                "")

#chk(change-case("The Foo Of Bar", "t"), "change-case t",  "The foo of bar")
#chk(change-case("The Foo Of Bar", "l"), "change-case l",  "the foo of bar")
#chk(change-case("The Foo Of Bar", "u"), "change-case u",  "THE FOO OF BAR")
#chk(change-case("FOO: The BAR baz", "t"), "change-case t colon", "Foo: The bar baz")
#chk(change-case("the {ACM} {SIG}", "t"), "change-case t braces", "the {ACM} {SIG}")
#chk(change-case("a {\\OE}uvre and {\\AA}ngstr", "t"), "change-case t foreign", "a {\\oe}uvre and {\\aa}ngstr")
#chk(change-case("title with {Nested {deep}}", "t"), "change-case t nested", "title with {Nested {deep}}")
#chk(change-case("Research Note", "t"), "change-case t simple", "Research note")

// Assert literal codepoints here; PDF text comparisons normalize combining accents.
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

// Inspect element kinds through repr because content equality retains empty sequence wrappers.
#let has(s, sub) = assert(repr(tex-to-content(s)).contains(sub),
  message: "tex-to-content(" + repr(s) + ") should contain a " + sub + " element\n  got: " + repr(tex-to-content(s)))
#has("x \\textbf{y}", "strong")
#has("a \\emph{b}", "emph")
#has("\\textit{b}", "styled")
#has("\\textsl{b}", "styled")
#has("\\textsc{acm}", "smallcaps")
#has("\\underline{u}", "underline")
// \textsuperscript needs context to read the surrounding text size.
#has("x\\textsuperscript{2}", "context")
#has("see \\url{http://a.b}", "link")
#has("ref \\href{http://a.b}{text}", "link")
#has("math $\\frac{n}{2} \\leq x^{2n}$", "equation")

// Typst treats a multi-letter math run as one identifier; the renderer must split it into atoms.
#has("$ab$", "[a]")
#has("$ab$", "[b]")
#has("$x_{ab}$", "attach")
#has("$x2$", "equation")
#has("\\ensuremath{\\alpha}", "equation")

// Evaluate every command mapping to catch invalid Typst symbol names.
#let math-symbols = (
  "alpha", "beta", "gamma", "delta", "epsilon", "varepsilon", "zeta", "eta",
  "theta", "vartheta", "iota", "kappa", "lambda", "mu", "nu", "xi", "omicron",
  "pi", "varpi", "rho", "varrho", "sigma", "varsigma", "tau", "upsilon", "phi",
  "varphi", "chi", "psi", "omega", "Gamma", "Delta", "Theta", "Lambda", "Xi",
  "Pi", "Sigma", "Upsilon", "Phi", "Psi", "Omega", "times", "cdot", "div", "pm",
  "mp", "ast", "star", "oplus", "otimes", "odot", "circ", "bullet", "cup", "cap",
  "setminus", "wedge", "land", "vee", "lor", "leq", "le", "geq", "ge", "neq",
  "ne", "approx", "equiv", "sim", "simeq", "cong", "propto", "ll", "gg", "to",
  "rightarrow", "Rightarrow", "leftarrow", "Leftarrow", "leftrightarrow", "mapsto",
  "infty", "partial", "nabla", "forall", "exists", "neg", "in", "notin", "ni",
  "subset", "subseteq", "supset", "supseteq", "emptyset", "varnothing", "perp",
  "parallel", "angle", "ell", "hbar", "aleph", "prime", "dag", "ddag", "ldots",
  "dots", "cdots", "sum", "prod", "int",
)
#let math-operators = (
  "log", "ln", "exp", "sin", "cos", "tan", "cot", "sec", "csc", "lim", "limsup",
  "liminf", "max", "min", "sup", "inf", "det", "dim", "gcd", "bmod",
)
#let math-functions-one = (
  "sqrt", "mathbb", "mathcal", "mathbf", "mathrm", "mathit", "mathsf", "mathtt",
  "mathfrak", "boldsymbol", "hat", "widehat", "tilde", "widetilde", "bar",
  "overline", "underline", "vec", "dot", "ddot", "check", "breve", "acute", "grave",
)
#let math-functions-two = ("frac", "tfrac", "dfrac", "binom")
#let math-noops = (
  "left", "right", "displaystyle", "textstyle", "scriptstyle", "limits", "nolimits",
  "bigl", "bigr", "big", "Big", "biggl", "biggr",
)
#let math-spacing-symbols = (",", ":", ">", ";", " ", "!")
#for command in math-symbols + math-operators {
  has("$\\" + command + "$", "equation")
}
#for command in math-functions-one {
  has("$\\" + command + "{x}$", "equation")
}
#for command in math-functions-two {
  has("$\\" + command + "{x}{y}$", "equation")
}
#for command in math-noops {
  has("$x \\" + command + " y$", "equation")
}
#for symbol in math-spacing-symbols {
  has("$a\\" + symbol + "b$", "equation")
}

#has("{\\it a b} c", "styled")
#has("{\\it a b} c", "[a b]")
#has("x {\\bf y z}", "strong")
#has("{\\sc a b}", "smallcaps")
#chk(tex-to-string("{\\it a b} c"), "switch drops formatting in string mode", "a b c")
#chk(tex-to-string("\\textit{a} b"), "arg-form styles only its argument", "a b")

#let _esc = tex-to-content("$\\text{a\"b\\c} + 1$")
#let _spc = tex-to-content("$a\\,b\\;c\\!d\\:e\\ f~g$")

#chk(tex-to-string("Caf\\'e"), "accent at end of field", "Cafe\u{0301}")
#chk(tex-to-string("a\\'e"),   "accent on lone trailing char", "ae\u{0301}")

// Exceed Typst's call-depth limit to check that token processing remains iterative.
#let _stress300 = "x" + ("\\'e" * 300)
#let _stressmath = "$" + ("a_1 + " * 200) + "b$"
#assert(repr(tex-to-content(_stress300)).len() > 0)
#assert(repr(tex-to-content(_stressmath)).contains("equation"))

// Expected \sf@size values come from probes against the bundled class (newtxmath).
#let sf(pt) = script-size(pt * tp) / tp
#for (size, want) in ((6, 5.5), (7, 5.5), (8, 6), (9, 6.6), (10, 7.3), (10.95, 8),
                      (12, 8.8), (14.4, 10.5), (17.28, 12.5), (20.74, 16.1)) {
  assert(calc.abs(sf(size) - want) < 0.001,
    message: "sf@size at " + str(size) + "pt: got " + repr(sf(size)) + ", want " + repr(want))
}
#assert(calc.abs(sf(9.5) - 6.65) < 0.001, message: "unlisted size falls back to 0.7x")
