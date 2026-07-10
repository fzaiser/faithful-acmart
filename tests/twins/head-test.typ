#import "/src/lib.typ": acmart, noindentparagraph
#show: acmart.with(format: "acmsmall", nonacm: true)

= Introduction
The quick brown fox jumps over the lazy dog. Pack my box with five dozen
liquor jugs. How vexingly quick daft zebras jump! The five boxing wizards
jump quickly. Sphinx of black quartz, judge my vow.

== Background and Motivation
Two driven jocks help fax my big quiz. Five quacking zephyrs jolt my wax bed.
The job requires extra pluck and zeal from every young wage earner.

=== A Finer Point
The quick brown fox jumps over the lazy dog. Pack my box with five dozen
liquor jugs. How vexingly quick daft zebras jump!

==== An inline heading
The five boxing wizards jump quickly. Sphinx of black quartz, judge my vow.
Two driven jocks help fax my big quiz.

#noindentparagraph[A margin run-in]
This no-indent run-in heading sits flush at the text margin with no trailing dot.

= Second Section
Five quacking zephyrs jolt my wax bed. The job requires extra pluck and zeal
from every young wage earner.

= Adjacent Headings
== Directly Nested
=== Immediately Run-In
Body text follows the run-in subsubsection with no intervening paragraph, so
the run-in sits flush at the text margin and each adjacent heading drops its
before-skip.
