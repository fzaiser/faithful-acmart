// Copyright / permission handling, transcribed from acmart.dtx
// (\@copyrightpermission and \@copyrightowner). The first-page copyright block is
//   <permission text>
//   © <year> <owner>
//   ACM <issn>/<year>/<month>-ART<article>
//   https://doi.org/<doi>
// For Creative Commons (copyright: "cc") the permission text is the CC license
// statement; set cc-type / cc-version on acmart() to choose the licence.


// Keep each mode's permission and owner together: the two values are a single
// choice in acmart, and a record prevents the tables from drifting apart.
#let _mode(permission, owner) = (permission: permission, owner: owner)
#let _copyright-modes = (
  "none": _mode(none, none),
  acmcopyright: _mode([Permission to make digital or hard copies of all or part of this work for personal or classroom use is granted without fee provided that copies are not made or distributed for profit or commercial advantage and that copies bear this notice and the full citation on the first page. Copyrights for components of this work owned by others than ACM must be honored. Abstracting with credit is permitted. To copy otherwise, or republish, to post on servers or to redistribute to lists, requires prior specific permission and\/or a fee. Request permissions from permissions\@acm.org.], [ACM.]),
  acmlicensed: _mode([Permission to make digital or hard copies of all or part of this work for personal or classroom use is granted without fee provided that copies are not made or distributed for profit or commercial advantage and that copies bear this notice and the full citation on the first page. Copyrights for components of this work owned by others than the author(s) must be honored. Abstracting with credit is permitted. To copy otherwise, or republish, to post on servers or to redistribute to lists, requires prior specific permission and\/or a fee. Request permissions from permissions\@acm.org.], [Copyright held by the owner/author(s). Publication rights licensed to ACM.]),
  rightsretained: _mode([Permission to make digital or hard copies of all or part of this work for personal or classroom use is granted without fee provided that copies are not made or distributed for profit or commercial advantage and that copies bear this notice and the full citation on the first page. Copyrights for third-party components of this work must be honored. For all other uses, contact the owner\/author(s).], [Copyright held by the owner/author(s).]),
  usgov: _mode([This paper is authored by an employee(s) of the United States Government and is in the public domain. Non-exclusive copying or redistribution is allowed, provided that the article citation is given and the authors and agency are clearly identified as its source. Request permissions from owner\/author(s).], none),
  usgovmixed: _mode([ACM acknowledges that this contribution was authored or co-authored by an employee, contractor, or affiliate of the United States government. As such, the United States government retains a nonexclusive, royalty-free right to publish or reproduce this article, or to allow others to do so, for government purposes only. Request permissions from owner\/author(s).], [Copyright held by the owner/author(s).]),
  cagov: _mode([This article was authored by employees of the Government of Canada. As such, the Canadian government retains all interest in the copyright to this work and grants to ACM a nonexclusive, royalty-free right to publish or reproduce this article, or to allow others to do so, provided that clear attribution is given both to the authors and the Canadian government agency employing them. Permission to make digital or hard copies for personal or classroom use is granted. Copies must bear this notice and the full citation on the first page. Copyrights for components of this work owned by others than the Canadian Government must be honored. To copy otherwise, distribute, republish, or post, requires prior specific permission and\/or a fee. Request permissions from owner\/author(s).], [Copyright Crown in Right of Canada.]),
  cagovmixed: _mode([ACM acknowledges that this contribution was co-authored by an affiliate of the national government of Canada. As such, the Crown in Right of Canada retains an equal interest in the copyright. Reprints must include clear attribution to ACM and the author's government agency affiliation. Permission to make digital or hard copies for personal or classroom use is granted. Copies must bear this notice and the full citation on the first page. Copyrights for components of this work owned by others than ACM must be honored. To copy otherwise, distribute, republish, or post, requires prior specific permission and\/or a fee. Request permissions from owner\/author(s).], [Copyright held by the owner/author(s).]),
  licensedusgovmixed: _mode([Publication rights licensed to ACM. ACM acknowledges that this contribution was authored or co-authored by an employee, contractor or affiliate of the United States government. As such, the Government retains a nonexclusive, royalty-free right to publish or reproduce this article, or to allow others to do so, for Government purposes only. Request permissions from owner\/author(s).], [Copyright held by the owner/author(s). Publication rights licensed to ACM.]),
  licensedcagov: _mode([This article was authored by employees of the Government of Canada. As such, the Canadian government retains all interest in the copyright to this work and grants to ACM a nonexclusive, royalty-free right to publish or reproduce this article, or to allow others to do so, provided that clear attribution is given both to the authors and the Canadian government agency employing them. Permission to make digital or hard copies for personal or classroom use is granted. Copies must bear this notice and the full citation on the first page. Copyrights for components of this work owned by others than the Canadian Government must be honored. To copy otherwise, distribute, republish, or post, requires prior specific permission and\/or a fee. Request permissions from owner\/author(s).], [Copyright held by the owner/author(s).]),
  licensedcagovmixed: _mode([Publication rights licensed to ACM. ACM acknowledges that this contribution was authored or co-authored by an employee, contractor or affiliate of the national government of Canada. As such, the Government retains a nonexclusive, royalty-free right to publish or reproduce this article, or to allow others to do so, for Government purposes only. Request permissions from owner\/author(s).], [Copyright held by the owner/author(s). Publication rights licensed to ACM.]),
  othergov: _mode([ACM acknowledges that this contribution was authored or co-authored by an employee, contractor or affiliate of a national government. As such, the Government retains a nonexclusive, royalty-free right to publish or reproduce this article, or to allow others to do so, for Government purposes only. Request permissions from owner\/author(s).], [Copyright held by the owner/author(s).]),
  licensedothergov: _mode([Publication rights licensed to ACM. ACM acknowledges that this contribution was authored or co-authored by an employee, contractor or affiliate of a national government. As such, the Government retains a nonexclusive, royalty-free right to publish or reproduce this article, or to allow others to do so, for Government purposes only. Request permissions from owner\/author(s).], [Copyright held by the owner/author(s). Publication rights licensed to ACM.]),
  iw3c2w3: _mode([This paper is published under the Creative Commons Attribution 4.0 International (CC-BY 4.0) license. Authors reserve their rights to disseminate the work on their personal and corporate Web sites with the appropriate attribution.], [IW3C2 (International World Wide Web Conference Committee), published under Creative Commons CC-BY 4.0 License.]),
  iw3c2w3g: _mode([This paper is published under the Creative Commons Attribution-NonCommercial-NoDerivs 4.0 International (CC-BY-NC-ND 4.0) license. Authors reserve their rights to disseminate the work on their personal and corporate Web sites with the appropriate attribution.], [IW3C2 (International World Wide Web Conference Committee), published under Creative Commons CC-BY-NC-ND 4.0 License.]),
  cc: _mode(none, [Copyright held by the owner/author(s).]),
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

// CC license statement (\@copyrightpermission case cc): the 88x31 licence badge
// (linked) on its own line, then the linked text statement. acmart draws the
// badge at height=5ex (~2.15x x-height); the SVGs live in src/assets/cc/.
#let cc-statement(cc-type, cc-version) = {
  assert(cc-type in _cc-names,
    message: "faithful-acmart: unsupported Creative Commons type " + repr(cc-type)
      + "; supported: " + repr(_cc-names.keys()))
  // CC0 is version 1.0 and ignores cc-version (its URL/name are fixed below); only
  // the graduated licences take 3.0/4.0.
  assert(cc-type == "zero" or cc-version in ("3.0", "4.0"),
    message: "faithful-acmart: unsupported Creative Commons version " + repr(cc-version)
      + "; supported: (\"3.0\", \"4.0\")")
  let url = if cc-type == "zero" {
    "https://creativecommons.org/publicdomain/zero/1.0"
  } else {
    "https://creativecommons.org/licenses/" + cc-type + "/" + cc-version
  }
  let name = _cc-names.at(cc-type)
  let suffix = if cc-type == "zero" { "" } else {
    " " + (if cc-version == "4.0" { "4.0 International" } else { "3.0 Unported" })
  }
  link(url, box(image("../assets/cc/cc-" + cc-type + ".svg", height: 2.15em)))
  linebreak()
  link(url)[This work is licensed under a Creative Commons #name#suffix License.]
}

// The full permission paragraph for a mode (CC computed from type/version).
#let permission-text(mode, cc-type: "by", cc-version: "4.0") = {
  assert(mode in _copyright-modes,
    message: "faithful-acmart: unsupported copyright mode " + repr(mode)
      + "; supported: " + repr(_copyright-modes.keys()))
  if mode == "cc" { cc-statement(cc-type, cc-version) }
  else { _copyright-modes.at(mode).permission }
}

#let copyright-owner(mode) = {
  assert(mode in _copyright-modes,
    message: "faithful-acmart: unsupported copyright mode " + repr(mode)
      + "; supported: " + repr(_copyright-modes.keys()))
  _copyright-modes.at(mode).owner
}
