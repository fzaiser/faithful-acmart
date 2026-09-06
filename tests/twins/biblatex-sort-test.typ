#import "/src/lib.typ": *
#show: acmart.with(format: "acmsmall", nonacm: true, bib-backend: "biblatex", cite-style: "author-year")

#heading(numbering: none, level: 1)[Names]
A name prefix files with the family name under one ACM style and only breaks a tie behind it under the other #cite("PfBachman", "PfBeethoven", "PfBergAl", "PfBergJan", "PfBergVan", "PfValois", "PfZorn", "PfVallee").
A name suffix is a key part of its own, behind the given name #cite("SfKing", "SfKingJr", "SfKingSr"), as is the given name itself #cite("GvNone", "GvAl", "GvAlan").
Every name part is padded to the longest of its kind in the list, so a second name can decide a comparison the first name would otherwise have lost #cite("PdTwo", "PdOne", "PdFamB", "PdFamA").
A trailing _and others_ is not a name and changes nothing #cite("OtOthers", "OtSolo", "OtPine").

#heading(numbering: none, level: 1)[What stands in for a name]
An entry with no name list at all files under its title, among the named ones #cite("NlAardvark", "NlLee", "NlMiddle", "NlNoe", "NlYar", "NlZebra"), and so does one led by a translator, because _usetranslator_ is off #cite("RlTranslator").
A _key_ field, on the other hand, becomes the whole sort key #cite("KyAaa", "KyZzz").
Punctuation stays in the key and weighs below the letters #cite("PnPlain", "PnQuote"), and a tie weighs below the letters like every other symbol #cite("TiTilde").

#heading(numbering: none, level: 1)[Tie-breakers]
Behind the name and the title come the year and the volume, both read as integers, so an entry missing either sorts after the ones that have it #cite("YrEarly", "YrLate", "YrNone") #cite("VlNone", "VlTwo", "VlRoman", "VlTen", "VlWord") #cite("IsNeg", "IsOne", "IsZero", "IsWord").
The fields that exist only to sort override what they shadow #cite("OvPresort", "OvSorttitle", "OvSortname", "OvSortyear", "OvPlainyear"), and case separates two entries nothing else can, uppercase first #cite("CsUpper", "CsLower").

#bibliography("/tests/twins/biblatex-sort-test.bib")
