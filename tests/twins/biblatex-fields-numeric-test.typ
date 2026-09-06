#import "/src/lib.typ": *
#show: acmart.with(format: "acmsmall", nonacm: true, bib-backend: "biblatex", cite-style: "numeric")

#heading(numbering: none, level: 1)[Dates]
A date field carries its day into every parenthesized date, and under the author-year style into the label date as well #cite("DtArticle", "DtMisc", "DtBook", "DtReport", "DtPatent").
A month is as far as a shorter date reaches #cite("DtMonth", "DtShortMonth"), and a separate day field reaches nothing at all, because biber drops it #cite("DtDayField").
A date beside a legacy year and month overwrites both, the way biber does when it parses one #cite("DtOverwrite").
A range prints both of its ends, each dropping what the other already says #cite("DtRange", "DtCrossRange", "DtYearRange"), and an open end keeps its dash with nothing behind it #cite("DtOpenRange").
A range can be open at its start instead, which leaves the year empty rather than missing #cite("DtOpenStart"), and one open at both ends is no date at all #cite("DtBothOpen").
A legacy year answers that start like any other component, and the range is no longer open #cite("DtLegacyStart").
A legacy month reaches it too, though only the year closes the range #cite("DtMonthOnly"), and a date field biber cannot read at all is ignored, range and everything #cite("DtNoDate").
A control symbol that stands for a character takes the first character slot itself, so what follows it is lowercased #cite("ScAmp", "ScPct").
A command that prints nothing, or only a space, leaves that slot to the word behind it #cite("ScRelax", "ScSpace", "ScSlash", "ScThin").

#heading(numbering: none, level: 1)[Types]
A type field naming a localization string prints that string #cite("TyCand", "TyRes", "TySoftware", "TyManual", "TyDataset", "TyPatent"), and a remapped thesis or techreport is given one of its own #cite("TyTechNone", "TyPhd", "TyMa").
A report that was always a report gets none #cite("TyReportNone"), and free text is printed as it stands #cite("TyFree"), including a value the _.bst_ backend would read as a missing-value marker #cite("TyMarker").
The table covers every string english.lbx puts in the type position, the bachelor thesis #cite("TyBachelor") and the patent requests #cite("TyPatreq", "TyPatrequs") included.

#heading(numbering: none, level: 1)[Name leads]
Only the drivers whose name macro reaches past the author lead with an editor or an organization #cite("LdEditorOne", "LdEditorTwo", "LdEditorMisc", "LdOrg").
The others print theirs further down instead #cite("LdArticle", "LdIncoll", "LdInproc"), as does a book that has an author too #cite("LdBoth").

#heading(numbering: none, level: 1)[Name lists]
A reference list shows at most nine names #cite("MbNine") before falling back to the first one and _et al._ #cite("MbTen", "MbTenEditors"), which an explicit _and others_ does not count towards #cite("MbNineOthers").

#heading(numbering: none, level: 1)[Sentence casing]
The numeric style sentence-cases a title by uppercasing its first character and lowercasing every letter after it, so a title opening with anything but a letter keeps the capitals it has #cite("ScDigit", "ScDigit2", "ScQuote", "ScParen"), a braced group is left alone #cite("ScBraced", "ScProtect", "ScAccWord"), an accent command is not the first character but the letter behind it is, through either set of braces #cite("ScAccent", "ScAccBrace", "ScAccGroup") and through a spelled-out accent #cite("ScWordAcc", "ScWordCed"), and neither a lowercase opening #cite("ScLower") nor a full stop inside the title #cite("ScShout", "ScPeriod") starts a new one.
A command that is itself a character takes the slot and is cased with it #cite("ScCharAe", "ScCharSs", "ScCharI"), unless it sits inside the title #cite("ScCharMid") or braced #cite("ScCharBrace").
Whitespace between such a command and what follows it is the delimiter TeX reads it as, not a character of the title #cite("ScWordSp", "ScCharSp", "ScSymSp", "ScSsSp").

#heading(numbering: none, level: 1)[Character macros]
A command that stands for a character sorts as that character rather than as nothing at all #cite("CmAdept", "CmAesop", "CmAlpha", "CmLima", "CmLodz", "CmLuna", "CmSmith", "CmSsmith", "CmSzabo").
Whitespace after a control word is part of it rather than part of the title #cite("CmSpace"), and the case a macro carries separates two entries that are otherwise equal #cite("CmCaseUpper", "CmCaseLower").

#heading(numbering: none, level: 1)[Truncated name lists]
A name list cut down to _et al._ ends in a full stop of its own, whichever list it is: a dataset's #cite("TrDataset"), a translator's #cite("TrTranslator"), a patent holder's #cite("TrHolder") or a book author's #cite("TrBookauthor").

#heading(numbering: none, level: 1)[Cite labels]
Only the author-year style disambiguates a cite label, so it alone tells two authors of a surname apart #cite-author("UnSmithJohn") #cite-author("UnSmithJane"), widens a name list past the truncation point #cite-author("UnListA") #cite-author("UnListB"), and drops a name prefix that the numeric style keeps #cite-author("UnPrefix").

#bibliography("/tests/twins/biblatex-fields-test.bib")
