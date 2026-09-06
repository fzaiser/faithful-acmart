#import "/src/lib.typ": *
#show: acmart.with(format: "acmsmall", nonacm: true, bib-backend: "biblatex", cite-style: "author-year")

#heading(numbering: none, level: 1)[Sorting]
#cite("NsAbe", "NsAeZed", "NsDeZed", "NsAlHakim", "NsFox"): a short dash-joined prefix leaves a name part before biber compares it, so the part files under the stem behind it whatever the case of the prefix, and a character command is one letter short of that pattern, so it files where its character does.

#cite("NsIbnSina"): three letters are too many for the pattern.

#cite("NsAbe", "NsProt", "NsFox"): a dash the braces protect is not the dash the pattern looks for, so the prefix stays and files with the rest of the part.

#cite("NsTitle"): a title is not a name at all.

#heading(numbering: none, level: 1)[Initialling]
Initials are read off the name as written, after the same prefix goes -- but only a lowercase one #cite-author("NiNoinit") #cite-author("NiQuirk") #cite-author("NiUpper") #cite-author("NiRho").
A braced given name is one word #cite-author("NiBraced") #cite-author("NiSage"), a hyphen protected by braces does not split it #cite-author("NiProtect") #cite-author("NiTell"), and a plain hyphen does #cite-author("NiHyphen") #cite-author("NiVane").
A character command is one letter here too #cite-author("NiChar") #cite-author("NiZeta"), and so is an accent, whatever braces protect it #cite-author("NiAccent") #cite-author("NiYew").
An initial that opens with a diacritic takes the letter behind it as well #cite-author("NiAli") #cite-author("NiWard").
Two such marks are two characters to biber and one quote once typeset, and a third is left out of the count #cite-author("NiAliTwo") #cite-author("NiXuThree") #cite-author("NiXu").
An initial of nothing but that quote keeps its period in an ordinary citation too #cite("NiAliTwo", "NiAli", "NiWard").
It keeps that period only where nothing precedes it, and loses it behind an earlier entry #cite("NsAbe", "NiAliTwo").
A label that merely opens with a period of its own keeps it wherever it sits #cite("NzBang", "NzDotNet").

#heading(numbering: none, level: 1)[Spelling]
#cite("NzEsc", "NzLit"): an accent spelled as a command and the same accent typed whole are one author, not two.

#cite("NzDotless", "NzDotted"): an accent over a dotless \\i is that same author too.

#bibliography("/tests/twins/biblatex-names-test.bib")
