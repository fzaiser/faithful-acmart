// Copyright / permission handling, transcribed from acmart.dtx
// (\@copyrightpermission and \@copyrightowner). The first-page copyright block is
//   <permission text>
//   © <year> <owner>
//   ACM <issn>/<year>/<month>-ART<article>
//   https://doi.org/<doi>
// For Creative Commons (copyright: "cc") the permission text is the CC license
// statement; set cc-type / cc-version on acmart() to choose the licence.

// Canned permission paragraphs by mode (\@copyrightpermission).
#let _permission = (
  "none": none,
  acmcopyright: [Permission to make digital or hard copies of all or part of this work for personal or classroom use is granted without fee provided that copies are not made or distributed for profit or commercial advantage and that copies bear this notice and the full citation on the first page. Copyrights for components of this work owned by others than ACM must be honored. Abstracting with credit is permitted. To copy otherwise, or republish, to post on servers or to redistribute to lists, requires prior specific permission and\/or a fee. Request permissions from permissions\@acm.org.],
  acmlicensed: [Permission to make digital or hard copies of all or part of this work for personal or classroom use is granted without fee provided that copies are not made or distributed for profit or commercial advantage and that copies bear this notice and the full citation on the first page. Copyrights for components of this work owned by others than the author(s) must be honored. Abstracting with credit is permitted. To copy otherwise, or republish, to post on servers or to redistribute to lists, requires prior specific permission and\/or a fee. Request permissions from permissions\@acm.org.],
  rightsretained: [Permission to make digital or hard copies of all or part of this work for personal or classroom use is granted without fee provided that copies are not made or distributed for profit or commercial advantage and that copies bear this notice and the full citation on the first page. Copyrights for third-party components of this work must be honored. For all other uses, contact the owner\/author(s).],
  usgov: [This paper is authored by an employee(s) of the United States Government and is in the public domain. Non-exclusive copying or redistribution is allowed, provided that the article citation is given and the authors and agency are clearly identified as its source. Request permissions from owner\/author(s).],
  usgovmixed: [ACM acknowledges that this contribution was authored or co-authored by an employee, contractor, or affiliate of the United States government. As such, the United States government retains a nonexclusive, royalty-free right to publish or reproduce this article, or to allow others to do so, for government purposes only. Request permissions from owner\/author(s).],
  iw3c2w3: [This paper is published under the Creative Commons Attribution 4.0 International (CC-BY 4.0) license. Authors reserve their rights to disseminate the work on their personal and corporate Web sites with the appropriate attribution.],
  iw3c2w3g: [This paper is published under the Creative Commons Attribution-NonCommercial-NoDerivs 4.0 International (CC-BY-NC-ND 4.0) license. Authors reserve their rights to disseminate the work on their personal and corporate Web sites with the appropriate attribution.],
)

// Copyright owner phrase for the "© year ..." line (\@copyrightowner).
#let _owner = (
  "none": none,
  acmcopyright: [ACM.],
  acmlicensed: [Copyright held by the owner/author(s). Publication rights licensed to ACM.],
  rightsretained: [Copyright held by the owner/author(s).],
  usgov: none,
  usgovmixed: [Copyright held by the owner/author(s).],
  iw3c2w3: [IW3C2 (International World Wide Web Conference Committee), published under Creative Commons CC-BY 4.0 License.],
  iw3c2w3g: [IW3C2 (International World Wide Web Conference Committee), published under Creative Commons CC-BY-NC-ND 4.0 License.],
  cc: [Copyright held by the owner/author(s).],
)

#let _cc-names = (
  "zero": "CC0 1.0 Universal",
  "by": "Attribution",
  "by-sa": "Attribution-ShareAlike",
  "by-nd": "Attribution-NoDerivatives",
  "by-nc": "Attribution-NonCommercial",
  "by-nc-sa": "Attribution-NonCommercial-ShareAlike",
  "by-nc-nd": "Attribution-NonCommercial-NoDerivatives",
)

// CC license statement (\@copyrightpermission case cc). The 88x31 licence badge
// image is omitted (not bundled); the linked text statement is reproduced.
#let cc-statement(cc-type, cc-version) = {
  let url = if cc-type == "zero" {
    "https://creativecommons.org/publicdomain/zero/1.0"
  } else {
    "https://creativecommons.org/licenses/" + cc-type + "/" + cc-version
  }
  let name = _cc-names.at(cc-type, default: "Attribution")
  let suffix = if cc-type == "zero" { "" } else {
    " " + (if cc-version == "4.0" { "4.0 International" } else { "3.0 Unported" })
  }
  link(url)[This work is licensed under a Creative Commons #name#suffix License.]
}

// The full permission paragraph for a mode (CC computed from type/version).
#let permission-text(mode, cc-type: "by", cc-version: "4.0") = {
  if mode == "cc" { cc-statement(cc-type, cc-version) }
  else { _permission.at(mode, default: _permission.acmlicensed) }
}

#let copyright-owner(mode) = _owner.at(mode, default: _owner.acmlicensed)
