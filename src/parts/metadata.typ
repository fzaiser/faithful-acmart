// Normalize document and publication metadata before rendering consumes it.

#import "frontmatter.typ": normalize-author
#import "journals.typ": lookup-journal
#import "strings.typ": lang-record

#let resolve-publication(journal, doi) = (
  journal: lookup-journal(journal),
  doi: if doi == none {
    none
  } else {
    (bare: doi, url: "https://doi.org/" + doi)
  },
)

#let resolve-conference(cfg, conference) = if conference == auto {
  if cfg.kind == "proceedings" {
    (name: "ACM Conference", short: "Conference'17",
     date: "July 2017", venue: "Washington, DC, USA")
  } else {
    none
  }
} else {
  conference
}

#let resolve-booktitle(conference, booktitle) = if booktitle != none {
  booktitle
} else if conference != none and conference.at("name", default: none) != none {
  let name = conference.name
  let short = conference.at("short", default: none)
  if short != none and short != name {
    [Proceedings of #name (#short)]
  } else {
    [Proceedings of #name]
  }
}

#let resolve-translations(lang, translations) = {
  let main-lang = if lang.main != none { lang.main } else { "english" }
  let fields = ("title", "subtitle", "keywords", "abstract")
  for (language, entry) in translations {
    let _ = lang-record(language)
    assert(language != main-lang,
      message: "faithful-acmart: `translations` includes the main language "
        + repr(language) + "; it is for OTHER languages (main is `language`).")
    for field in entry.keys() {
      assert(field in fields,
        message: "faithful-acmart: `translations." + language + "` has unknown field "
          + repr(field) + "; expected any of " + repr(fields) + ".")
    }
  }
  let pick(field) = translations.pairs()
    .filter(pair => field in pair.at(1))
    .map(pair => (pair.at(0), pair.at(1).at(field)))
  (
    title: pick("title"),
    subtitle: pick("subtitle"),
    keywords: pick("keywords"),
    abstract: pick("abstract"),
  )
}

#let document-fields(authors, anonymous, keywords) = (
  authors: if anonymous {
    ("Anonymous Author(s)",)
  } else {
    authors.map(author => author.name).filter(name => type(name) == str)
  },
  keywords: if type(keywords) == array {
    keywords.filter(keyword => type(keyword) == str)
  } else if type(keywords) == str {
    (keywords,)
  } else {
    ()
  },
)

// `data` contains the public metadata arguments after class options have been
// resolved. The returned `meta` record is the only representation consumed by
// front matter and page chrome.
#let resolve-metadata(cfg, lang, data) = {
  let authors = data.authors.map(normalize-author)
  let translated = resolve-translations(lang, data.translations)
  let publication = resolve-publication(data.journal, data.doi)
  let conference = resolve-conference(cfg, data.conference)
  let booktitle = resolve-booktitle(conference, data.booktitle)
  let copyright-year = if data.copyright-year != none {
    data.copyright-year
  } else {
    data.acm-year
  }
  let document = document-fields(authors, data.anonymous, data.keywords)

  (
    meta: (
      title: data.title,
      subtitle: data.subtitle,
      title-note: data.title-note,
      subtitle-note: data.subtitle-note,
      authors: authors,
      abstract: data.abstract,
      ccs: data.ccs,
      keywords: data.keywords,
      strings: cfg.strings,
      translated-title: translated.title,
      translated-subtitle: translated.subtitle,
      translated-keywords: translated.keywords,
      translated-abstract: translated.abstract,
      teaser: data.teaser,
      journal: publication.journal,
      acm-volume: data.acm-volume,
      acm-number: data.acm-number,
      acm-article: data.acm-article,
      acm-year: data.acm-year,
      acm-month: data.acm-month,
      doi: publication.doi,
      conference: conference,
      booktitle: booktitle,
      isbn: data.isbn,
      code-data-link: data.code-data-link,
      contributions: data.contributions,
      acmcp-logo: data.acmcp-logo,
      engage-metadata: data.engage-metadata,
      bibstrip: cfg.bibstrip,
      authors-per-row: data.authors-per-row,
      copyright: data.copyright,
      copyright-year: copyright-year,
      cc-type: data.cc-type,
      cc-version: data.cc-version,
      print-acm-reference: data.print-acm-reference,
      print-ccs: data.print-ccs,
      nonacm: data.nonacm,
      author-version: data.author-version,
      author-draft: data.author-draft,
      anonymous: data.anonymous,
      submission-id: data.submission-id,
      start-page: data.start-page,
      thanks: data.thanks,
      authors-addresses: data.authors-addresses,
      editors: data.editors,
    ),
    document: document,
    force-screen: publication.journal.screen,
  )
}
