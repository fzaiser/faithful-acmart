// Title block / frontmatter for acmsmall (journal layout).
//
// Mirrors acmart's \maketitle for the journal formats: title (LARGE sans bold,
// left aligned), author lines (large sans uppercase names + small serif
// affiliation, grouped by shared affiliation), then abstract / CCS / keywords /
// ACM reference format. See the acmsmall-frontmatter-specs memory for sources.

#import "copyright.typ": permission-text, copyright-owner
#import "spacing.typ": comp, tex-skip

#let fnsymbols = ("*", "†", "‡", "§", "¶", "‖", "**", "††", "‡‡")

#let month-names = (
  "January", "February", "March", "April", "May", "June",
  "July", "August", "September", "October", "November", "December",
)

// journal key -> (name, short, issn). issn is acmart's \@permissionCodeTwo
// (falling back to \@permissionCodeOne when Two is absent), used in the
// "ACM <issn>/<year>/<month>-ART<article>" copyright line; `short` is the
// running-head/footer abbreviation. Transcribed in full from acmart.dtx's
// \acmJournal choice table (the dummy FACMP fallback is intentionally omitted).
#let journals = (
  ACMJCSS: (name: "ACM Journal on Computing and Sustainable Societies", short: "ACM J. Comput. Sustain. Soc.", issn: "2834-5533"),
  ACMJDS: (name: "ACM Journal of Data Science", short: "ACM J. Data Sci.", issn: "3069-3497"),
  AILET: (name: "ACM AI Letters", short: "ACM AI Lett.", issn: "3068-8590"),
  CIE: (name: "ACM Computers in Entertainment", short: "ACM Comput. Entertain.", issn: "1544-3574"),
  CSUR: (name: "ACM Computing Surveys", short: "ACM Comput. Surv.", issn: "1557-7341"),
  DGOV: (name: "Digital Government: Research and Practice", short: "Digit. Gov. Res. Pract.", issn: "2639-0175"),
  DLT: (name: "Distributed Ledger Technologies: Research and Practice", short: "Distrib. Ledger Technol.", issn: "2769-6480"),
  DTRAP: (name: "Digital Threats: Research and Practice", short: "Digit. Threat. Res. Pract.", issn: "2576-5337"),
  FAC: (name: "Formal Aspects of Computing", short: "Form. Asp. Comput.", issn: "1433-299X"),
  GAMES: (name: "ACM Games: Research and Practice", short: "ACM Games", issn: "2832-5516"),
  HEALTH: (name: "ACM Transactions on Computing for Healthcare", short: "ACM Trans. Comput. Healthcare", issn: "2637-8051"),
  IMWUT: (name: "Proceedings of the ACM on Interactive, Mobile, Wearable and Ubiquitous Technologies", short: "Proc. ACM Interact. Mob. Wearable Ubiquitous Technol.", issn: "2474-9567"),
  JACM: (name: "Journal of the ACM", short: "J. ACM", issn: "1557-735X"),
  JATS: (name: "Journal on Autonomous Transportation Systems", short: "ACM J. Auton. Transport. Syst.", issn: "2833-0528"),
  JDIQ: (name: "ACM Journal of Data and Information Quality", short: "ACM J. Data Inform. Quality", issn: "1936-1963"),
  JDS: (name: "ACM Journal of Data Science", short: "ACM J. Data Sci.", issn: "2831-3194"),
  JEA: (name: "ACM Journal of Experimental Algorithmics", short: "ACM J. Exp. Algor.", issn: "1084-6654"),
  JERIC: (name: "ACM Journal of Educational Resources in Computing", short: "ACM J. Edu. Resources in Comput.", issn: "1073-0516"),
  JETC: (name: "ACM Journal on Emerging Technologies in Computing Systems", short: "ACM J. Emerg. Technol. Comput. Syst.", issn: "1550-4840"),
  JOCCH: (name: "ACM Journal on Computing and Cultural Heritage", short: "ACM J. Comput. Cult. Herit.", issn: "1556-4711"),
  JRC: (name: "ACM Journal on Responsible Computing", short: "ACM J. Responsib. Comput.", issn: "2832-0565"),
  PACMCGIT: (name: "Proceedings of the ACM on Computer Graphics and Interactive Techniques", short: "Proc. ACM Comput. Graph. Interact. Tech.", issn: "2577-6193"),
  PACMHCI: (name: "Proceedings of the ACM on Human-Computer Interaction", short: "Proc. ACM Hum.-Comput. Interact.", issn: "2573-0142"),
  PACMMOD: (name: "Proceedings of the ACM on Management of Data", short: "Proc. ACM Manag. Data", issn: "2836-6573"),
  PACMNET: (name: "Proceedings of the ACM on Networking", short: "Proc. ACM Netw.", issn: "2834-5509"),
  PACMPL: (name: "Proceedings of the ACM on Programming Languages", short: "Proc. ACM Program. Lang.", issn: "2475-1421"),
  PACMSE: (name: "Proceedings of the ACM on Software Engineering", short: "Proc. ACM Softw. Eng.", issn: "2994-970X"),
  POMACS: (name: "Proceedings of the ACM on Measurement and Analysis of Computing Systems", short: "Proc. ACM Meas. Anal. Comput. Syst.", issn: "2476-1249"),
  TAAS: (name: "ACM Transactions on Autonomous and Adaptive Systems", short: "ACM Trans. Autonom. Adapt. Syst.", issn: "1556-4703"),
  TACCESS: (name: "ACM Transactions on Accessible Computing", short: "ACM Trans. Access. Comput.", issn: "1936-7236"),
  TACO: (name: "ACM Transactions on Architecture and Code Optimization", short: "ACM Trans. Arch. Code Optim.", issn: "1544-3973"),
  TAIS: (name: "ACM Transactions on AI for Science", short: "ACM Trans. AI Sci.", issn: "3066-4438"),
  TAISAP: (name: "ACM Transactions on AI Security and Privacy", short: "ACM Trans. AI Secur. Priv.", issn: "3068-3564"),
  TALG: (name: "ACM Transactions on Algorithms", short: "ACM Trans. Algor.", issn: "1549-6333"),
  TALLIP: (name: "ACM Transactions on Asian and Low-Resource Language Information Processing", short: "ACM Trans. Asian Low-Resour. Lang. Inf. Process.", issn: "2375-4702"),
  TAP: (name: "ACM Transactions on Applied Perception", short: "ACM Trans. Appl. Percept.", issn: "1544-3965"),
  TCPS: (name: "ACM Transactions on Cyber-Physical Systems", short: "ACM Trans. Cyber-Phys. Syst.", issn: "2378-9638"),
  TDS: (name: "ACM Transactions on Data Science", short: "ACM Trans. Data Sci.", issn: "2577-3224"),
  TEAC: (name: "ACM Transactions on Economics and Computation", short: "ACM Trans. Econ. Comput.", issn: "2167-8383"),
  TECS: (name: "ACM Transactions on Embedded Computing Systems", short: "ACM Trans. Embedd. Comput. Syst.", issn: "1558-3465"),
  TELO: (name: "ACM Transactions on Evolutionary Learning and Optimization", short: "ACM Trans. Evol. Learn. Optim.", issn: "2688-3007"),
  THRI: (name: "ACM Transactions on Human-Robot Interaction", short: "ACM Trans. Hum.-Robot Interact.", issn: "2573-9522"),
  TIIS: (name: "ACM Transactions on Interactive Intelligent Systems", short: "ACM Trans. Interact. Intell. Syst.", issn: "2160-6463"),
  TIOT: (name: "ACM Transactions on Internet of Things", short: "ACM Trans. Internet Things", issn: "2577-6207"),
  TISSEC: (name: "ACM Transactions on Information and System Security", short: "ACM Trans. Info. Syst. Sec.", issn: "1094-9224"),
  TIST: (name: "ACM Transactions on Intelligent Systems and Technology", short: "ACM Trans. Intell. Syst. Technol.", issn: "2157-6912"),
  TKDD: (name: "ACM Transactions on Knowledge Discovery from Data", short: "ACM Trans. Knowl. Discov. Data.", issn: "1556-472X"),
  TMIS: (name: "ACM Transactions on Management Information Systems", short: "ACM Trans. Manag. Inform. Syst.", issn: "2158-6578"),
  TOCE: (name: "ACM Transactions on Computing Education", short: "ACM Trans. Comput. Educ.", issn: "1946-6226"),
  TOCHI: (name: "ACM Transactions on Computer-Human Interaction", short: "ACM Trans. Comput.-Hum. Interact.", issn: "1557-7325"),
  TOCL: (name: "ACM Transactions on Computational Logic", short: "ACM Trans. Comput. Logic", issn: "1557-945X"),
  TOCS: (name: "ACM Transactions on Computer Systems", short: "ACM Trans. Comput. Syst.", issn: "1557-7333"),
  TOCT: (name: "ACM Transactions on Computation Theory", short: "ACM Trans. Comput. Theory", issn: "1942-3462"),
  TODAES: (name: "ACM Transactions on Design Automation of Electronic Systems", short: "ACM Trans. Des. Autom. Electron. Syst.", issn: "1557-7309"),
  TODS: (name: "ACM Transactions on Database Systems", short: "ACM Trans. Datab. Syst.", issn: "1557-4644"),
  TOG: (name: "ACM Transactions on Graphics", short: "ACM Trans. Graph.", issn: "1557-7368"),
  TOIS: (name: "ACM Transactions on Information Systems", short: "ACM Trans. Inf. Syst.", issn: "1558-2868"),
  TOIT: (name: "ACM Transactions on Internet Technology", short: "ACM Trans. Internet Technol.", issn: "1557-6051"),
  TOMACS: (name: "ACM Transactions on Modeling and Computer Simulation", short: "ACM Trans. Model. Comput. Simul.", issn: "1558-1195"),
  TOMM: (name: "ACM Transactions on Multimedia Computing, Communications and Applications", short: "ACM Trans. Multimedia Comput. Commun. Appl.", issn: "1551-6865"),
  TOMPECS: (name: "ACM Transactions on Modeling and Performance Evaluation of Computing Systems", short: "ACM Trans. Model. Perform. Eval. Comput. Syst.", issn: "2376-3647"),
  TOMS: (name: "ACM Transactions on Mathematical Software", short: "ACM Trans. Math. Softw.", issn: "1557-7295"),
  TOPC: (name: "ACM Transactions on Parallel Computing", short: "ACM Trans. Parallel Comput.", issn: "2329-4957"),
  TOPLAS: (name: "ACM Transactions on Programming Languages and Systems", short: "ACM Trans. Program. Lang. Syst.", issn: "1558-4593"),
  TOPML: (name: "ACM Transactions on Probabilistic Machine Learning", short: "ACM Trans. Probab. Mach. Learn.", issn: "2836-8924"),
  TOPS: (name: "ACM Transactions on Privacy and Security", short: "ACM Trans. Priv. Sec.", issn: "2471-2574"),
  TORS: (name: "ACM Transactions on Recommender Systems", short: "ACM Trans. Recomm. Syst.", issn: "2770-6699"),
  TOS: (name: "ACM Transactions on Storage", short: "ACM Trans. Storage", issn: "1553-3093"),
  TOSEM: (name: "ACM Transactions on Software Engineering and Methodology", short: "ACM Trans. Softw. Eng. Methodol.", issn: "1557-7392"),
  TOSN: (name: "ACM Transactions on Sensor Networks", short: "ACM Trans. Sensor Netw.", issn: "1550-4867"),
  TQC: (name: "ACM Transactions on Quantum Computing", short: "ACM Trans. Quantum Comput.", issn: "2643-6817"),
  TRETS: (name: "ACM Transactions on Reconfigurable Technology and Systems", short: "ACM Trans. Reconfig. Technol. Syst.", issn: "1936-7414"),
  TSAS: (name: "ACM Transactions on Spatial Algorithms and Systems", short: "ACM Trans. Spatial Algorithms Syst.", issn: "2374-0361"),
  TSC: (name: "ACM Transactions on Social Computing", short: "ACM Trans. Soc. Comput.", issn: "2469-7826"),
  TSLP: (name: "ACM Transactions on Speech and Language Processing", short: "ACM Trans. Speech Lang. Process.", issn: "2329-9304"),
  TWEB: (name: "ACM Transactions on the Web", short: "ACM Trans. Web", issn: "1559-114X"),
)

#let lookup-journal(key) = {
  if key == none { return (name: none, short: none, issn: "XXXX-XXXX") }
  let s = str(key)
  journals.at(s, default: (name: s, short: s, issn: "XXXX-XXXX"))
}

#let pub-date(meta) = {
  let parts = ()
  if meta.acm-month != none { parts.push(month-names.at(meta.acm-month - 1)) }
  if meta.acm-year != none { parts.push(str(meta.acm-year)) }
  parts.join(" ")
}

// Join a list of name strings the ACM/amsart "andify" way.
#let andify(names) = {
  let n = names.len()
  if n == 0 { return none }
  if n == 1 { return names.at(0) }
  if n == 2 { return names.at(0) + " and " + names.at(1) }
  names.slice(0, n - 1).join(", ") + ", and " + names.at(n - 1)
}

// An author's `affiliation` may be a single dict or an array of dicts (a person
// with several affiliations, like LaTeX's repeated \affiliation). Normalize to a
// list of dicts; none -> empty list.
#let affil-list(aff) = {
  if aff == none { () } else if type(aff) == array { aff } else { (aff,) }
}

// Title-block affiliation: institution, country (city/state go to contact info).
// Multiple affiliations are joined with " and ", as LaTeX joins institutions.
#let affil-short(aff) = {
  let one(a) = {
    let parts = ()
    if a.at("institution", default: none) != none { parts.push(a.institution) }
    if a.at("country", default: none) != none { parts.push(a.country) }
    parts.join(", ")
  }
  let s = affil-list(aff).map(one).filter(p => p != "").join(" and ")
  if s == "" { none } else { s }
}

// Group consecutive authors that share an identical affiliation.
#let group-authors(authors) = {
  let groups = ()
  for a in authors {
    let aff = a.at("affiliation", default: none)
    if groups.len() > 0 and groups.last().affiliation == aff {
      groups.last().authors.push(a)
    } else {
      groups.push((affiliation: aff, authors: (a,)))
    }
  }
  groups
}

// CCS concepts: group by area (preserving order), style specifics by
// significance (>=500 bold, >=300 italic, else roman), join with "; ",
// bullet + bold area + arrow per group, trailing period. Input: list of
// (significance, area, specific) tuples (mirrors \ccsdesc[sig]{area~specific}).
#let render-ccs-concepts(ccs) = {
  // preserve area order
  let areas = ()
  let by-area = (:)
  for entry in ccs {
    let (sig, area, ..rest) = entry
    let spec = if rest.len() > 0 { rest.at(0) } else { none }
    if area not in by-area {
      by-area.insert(area, ())
      areas.push(area)
    }
    if spec != none and spec != "" {
      by-area.at(area).push((sig: sig, spec: spec))
    }
  }
  let style-spec(s) = {
    if s.sig >= 500 { strong(s.spec) }
    else if s.sig >= 300 { emph(s.spec) }
    else { s.spec }
  }
  // \ccsdesc separates every concept (areas and specifics) with "; " and ends
  // with "." (acmart.dtx:5994-6006), so areas are joined by "; " too.
  for (i, area) in areas.enumerate() {
    if i > 0 { [; ] }
    [• #strong(area)]
    let specs = by-area.at(area)
    if specs.len() > 0 {
      [ → ]
      specs.map(style-spec).join("; ")
    }
  }
  [.]
}

// A 9pt "Label: content" line used for CCS Concepts and Keywords.
// \@specialsection does `\par\medskip\small ...`, so the gap is \medskip before
// 9pt text (tex-skip with sz: "small"). See DESIGN.md "block vertical spacing".
#let special-line(cfg, label, content) = {
  let lead = comp(cfg, sz: "small")
  v(tex-skip(cfg, cfg.medskip, sz: "small"), weak: true)
  block(width: 100%, spacing: lead)[
    #set text(font: cfg.fonts.serif, size: cfg.size.small)
    #set par(justify: false, leading: lead, first-line-indent: 0pt, spacing: lead)
    #label: #content
  ]
}

// Assign footnote symbols to author notes (deduplicating identical notes), and
// compute each author's superscript marks (corresponding ✉ then note symbol).
#let collect-notes(authors) = {
  let notes = ()
  let seen = (:)
  let marks = ()
  for a in authors {
    let m = ()
    if a.at("corresponding", default: false) { m.push("✉") }
    let note = a.at("note", default: none)
    if note != none {
      let key = repr(note)
      if key not in seen {
        seen.insert(key, fnsymbols.at(notes.len()))
        notes.push((symbol: seen.at(key), body: note))
      }
      m.push(seen.at(key))
    }
    marks.push(m)
  }
  (notes: notes, marks: marks)
}

// One author's contact entry, replaying name → affiliation fields → email in
// that order (email LAST), matching LaTeX \@mkauthorsaddresses (acmart.dtx:7588).
// Authors are listed individually in source order with the affiliation repeated
// per author — NOT grouped. (LaTeX also allows multiple affiliations per author,
// joined by " and "; our data model carries one affiliation each.)
#let contact-line(a) = {
  let parts = (a.name,)
  // each affiliation as "institution, city, state, country"; several joined by
  // " and " (LaTeX's institution separator), then email last.
  let affs = affil-list(a.at("affiliation", default: none)).map(aff => {
    ("institution", "city", "state", "country")
      .map(k => aff.at(k, default: none)).filter(v => v != none).join(", ")
  }).filter(s => s != "")
  if affs.len() > 0 { parts.push(affs.join(" and ")) }
  if a.at("email", default: none) != none { parts.push(a.email) }
  parts.join(", ")
}

// The page-1 footnote stack: author notes, authors' contact information, and the
// copyright/permission block, each with a rule above. Placed at the bottom of
// the first page's text area.
#let make-footnotes(cfg, meta) = {
  let fs = cfg.size.footnotesize
  let lead = comp(cfg, sz: "footnotesize")
  let ni = collect-notes(meta.authors)
  let j = lookup-journal(meta.journal)

  let rule(width) = {
    v(cfg.footnote-rule-kern-above, weak: true)
    line(length: width, stroke: 0.4pt)
    v(cfg.footnote-rule-kern-below, weak: true)
  }

  let stack = {
    set text(font: cfg.fonts.serif, size: fs)
    set par(justify: true, leading: lead, first-line-indent: 0pt, spacing: lead)

    let anon = meta.at("anonymous", default: false)

    // 1. Author notes (regular footnotes, symbol marks)
    if not anon and ni.notes.len() > 0 {
      rule(cfg.footnote-rule-short)
      for n in ni.notes {
        block(spacing: lead)[#super(n.symbol)#n.body]
      }
    }

    // 2. Authors' Contact Information (suppressed in anonymous mode)
    if not anon and meta.authors.len() > 0 and meta.authors.any(a => a.at("affiliation", default: none) != none or a.at("email", default: none) != none) {
      rule(100%)
      let label = if meta.authors.len() > 1 { "Authors' Contact Information:" } else { "Author's Contact Information:" }
      let contacts = meta.authors.map(contact-line).join("; ")
      block(spacing: lead)[#label #contacts.]
    }

    // 3. Copyright / permission (faithful to acmart's assembly)
    rule(100%)
    block(spacing: lead, {
      let mode = meta.copyright
      let ptext = permission-text(mode, cc-type: meta.cc-type, cc-version: meta.cc-version)
      if ptext != none { ptext; parbreak() }
      set par(justify: false)
      // © <year> <owner>
      let owner = copyright-owner(mode)
      if owner != none {
        let y = if meta.copyright-year != none { str(meta.copyright-year) } else { "" }
        [© #y #owner]
        linebreak()
      } else if meta.copyright-year != none {
        [#str(meta.copyright-year). ]
      }
      // journal bibstrip: ACM <issn>/<year>/<month>-ART<article> then DOI
      // (acmart.dtx:6651). \@acmArticle defaults to empty, so ART may have no number.
      [ACM #j.issn/#str(meta.acm-year)/#str(meta.acm-month)-ART#{
        if meta.acm-article != none { str(meta.acm-article) }
      }]
      if meta.doi != none {
        linebreak()
        link("https://doi.org/" + meta.doi)[https:\/\/doi.org\/#meta.doi]
      }
    })
  }

  // float: true so the block reserves space at the bottom of the first page and
  // the body text flows above it (rather than overlapping).
  place(bottom, float: true, block(width: 100%, spacing: 0pt, stack))
}

#let make-title(cfg, meta) = {
  // --- Title (LARGE sans bold, left-aligned) ---
  block(spacing: 0pt)[
    // top-edge: cap-height places the (tall) first line's cap-top at the top
    // margin, matching LaTeX \topskip behaviour for a first line taller than it.
    #set text(font: cfg.fonts.sans, weight: "bold", size: cfg.size.LARGE, top-edge: "cap-height")
    #set par(justify: false, leading: comp(cfg, sz: "LARGE"))
    #meta.title
  ]
  // Subtitle (\@subtitlefont = \normalsize\mdseries, inherits the sans family);
  // its own block so it gets normalsize leading, not the title's LARGE leading.
  // LaTeX `\par` puts it one normalsize baselineskip below the title.
  if meta.subtitle != none {
    block(spacing: tex-skip(cfg, 0pt))[
      #set text(font: cfg.fonts.sans, weight: "regular", size: cfg.font-size)
      #set par(justify: false, leading: comp(cfg))
      #meta.subtitle
    ]
  }

  // Title box ends with \par\bigskip; \@mkauthors@i prepends \par\medskip before
  // the author lines (at \large). So the gap is \bigskip + \medskip before 10.95pt.
  v(tex-skip(cfg, cfg.bigskip + cfg.medskip, sz: "large"), weak: true)

  // --- Authors (grouped by affiliation) ---
  // Anonymous review: replace the whole author strip with "Anonymous Author(s)".
  if meta.at("anonymous", default: false) {
    block(spacing: 0pt)[
      #set text(font: cfg.fonts.sans, size: cfg.size.large)
      #upper[Anonymous Author(s)]
    ]
    // author box trailing \par\medskip; next block (abstract/CCS/...) is 9pt
    v(tex-skip(cfg, cfg.medskip, sz: "small"), weak: true)
  } else {
  let ni = collect-notes(meta.authors)
  let marked = meta.authors.enumerate().map(((i, a)) => {
    let a2 = a
    a2.insert("_marks", ni.marks.at(i))
    a2
  })
  block(spacing: 0pt)[
    #set par(justify: false, leading: comp(cfg, sz: "large"), spacing: 0pt)
    #for g in group-authors(marked) {
      let names = g.authors.map(a => {
        upper(a.name)
        // note marks (superscript symbols); the ✉ glyph is large, so shrink it
        for m in a._marks {
          if m == "✉" { super(text(size: 0.72em)[#m]) } else { super(m) }
        }
      })
      block(spacing: comp(cfg, sz: "large"))[
        #text(font: cfg.fonts.sans, size: cfg.size.large)[#{
          // join names with "and"/", and" while preserving content marks
          let n = names.len()
          if n == 1 { names.at(0) }
          else if n == 2 { names.at(0) + " and " + names.at(1) }
          else {
            for (i, nm) in names.enumerate() {
              nm
              if i < n - 2 { ", " } else if i == n - 2 { ", and " }
            }
          }
        }]#{
          let aff = affil-short(g.affiliation)
          if aff != none {
            text(font: cfg.fonts.serif, size: cfg.size.small)[, #aff]
          }
        }
      ]
    }
  ]

  // author box trailing \par\medskip; next block (abstract/CCS/...) is 9pt
  v(tex-skip(cfg, cfg.medskip, sz: "small"), weak: true)
  } // end non-anonymous author block

  // --- Abstract (9pt, no heading label, first line not indented) ---
  if meta.abstract != none {
    block(width: 100%, spacing: 0pt)[
      #set text(font: cfg.fonts.serif, size: cfg.size.small)
      #set par(justify: true, leading: comp(cfg, sz: "small"),
        first-line-indent: (amount: cfg.parindent, all: false),
        spacing: comp(cfg, sz: "small"))
      #meta.abstract
    ]
  }

  // --- CCS Concepts ---
  if meta.ccs != none {
    special-line(cfg, [CCS Concepts], render-ccs-concepts(meta.ccs))
  }

  // --- Keywords ---
  if meta.keywords != none {
    let kw = if type(meta.keywords) == array { meta.keywords.join(", ") } else { meta.keywords }
    // journals use \keywordsname = "Additional Key Words and Phrases" (acmart.dtx:3294);
    // plain "Keywords" is only for the conference formats.
    special-line(cfg, [Additional Key Words and Phrases], kw)
  }

  // --- ACM Reference Format ---
  if meta.show-ref {
    let j = lookup-journal(meta.journal)
    // \@mkbibcitation does `\par\medskip\small ...`; next block is 9pt
    v(tex-skip(cfg, cfg.medskip, sz: "small"), weak: true)
    context {
      let total = counter(page).final().first()
      block(width: 100%, spacing: 0pt)[
        #set text(font: cfg.fonts.serif, size: cfg.size.small)
        #set par(justify: true, leading: comp(cfg, sz: "small"),
          first-line-indent: 0pt, spacing: comp(cfg, sz: "small"))
        #strong[ACM Reference Format:]\
        #{ if meta.at("anonymous", default: false) [Anonymous Author(s)] else { andify(meta.authors.map(a => a.name)) } }. #str(meta.acm-year). #meta.title#{
          if meta.subtitle != none [: #meta.subtitle]
        }. #if j.short != none { emph(j.short) + " " }#{
          let parts = ()
          if meta.acm-volume != none { parts.push(str(meta.acm-volume)) }
          if meta.acm-number != none { parts.push(str(meta.acm-number)) }
          parts.join(", ")
        }#if meta.acm-article != none [, Article #str(meta.acm-article)] (#pub-date(meta)), #total #if total == 1 [page] else [pages].#{
          if meta.doi != none [ #link("https://doi.org/" + meta.doi)[https:\/\/doi.org\/#meta.doi]]
        }
      ]
    }
  }

  // \@printendtopmatter \par\bigskip; next block is the body at 10pt
  v(tex-skip(cfg, cfg.bigskip), weak: true)
}
