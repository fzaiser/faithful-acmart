// sample-sigconf-i13n — port of the upstream acmart sample (acmart/samples,
// docstrip option `all,proceedings,sigconf,i13n`). The sigconf proceedings
// format with secondary-language top matter: \translatedtitle and
// translatedabstract in French/German/Spanish (English is the main language —
// the last entry of the `language` list). Diffed against
// out/latex/sigconf-i13n.pdf.
#import "/src/lib.typ": acmart
#import "_sample-common.typ": sample-authors, sample-abstract, sample-ccs, sample-received, sample-body

#show: acmart.with(
  format: "sigconf",
  language: ("french", "german", "spanish", "english"),
  title: "The Name of the Title Is Hope",
  translated-title: (
    french: "Le nom du titre est l'espoir",
    german: "Der Name des Titels ist 'Hoffnung'",
    spanish: "El nombre del título es esperanza",
  ),
  translated-abstract: (
    french: [
      Un document LaTeX clair et bien documenté est présenté comme un article
      formaté pour publication par ACM dans les actes d'une conférence ou parution
      dans une revue. Basé sur la classe de document "acmart", ce l'article
      présente et explique de nombreuses variations courantes, ainsi que autant
      d'éléments de mise en forme qu'un auteur peut utiliser dans le préparation de
      la documentation de leur travail.
    ],
    german: [
      Es wird ein übersichtliches und gut dokumentiertes LaTeX-Dokument
      präsentiert, welches für die Veröffentlichung durch ACM in einem Tagungsband
      oder als Zeitschriftenpublikation formatiert wurde. Basierend auf der
      Dokumentenklasse "acmart" präsentiert und erklärt dieser Artikel viele der
      Formatierungselemente sowie auch viele der gängigen Variationen, die ein
      Autor bei der Beschreibung seiner Arbeit verwenden darf.
    ],
    spanish: [
      Un documento LaTeX claro y bien documentado se presenta como un artículo
      formateado para su publicación por ACM en las actas de una conferencia o
      publicación de una revista. Basado en la clase de documento "acmart", este
      artículo presenta y explica muchas de las variaciones comunes, así como
      tantos de los elementos de formato que un autor puede usar en el preparación
      de la documentación de su trabajo.
    ],
  ),
  teaser: figure(
    image("/acmart/samples/sampleteaser.jpg", width: 100%,
      alt: "Enjoying the baseball game from the third-base seats. " +
           "Ichiro Suzuki preparing to bat."),
    caption: [Seattle Mariners at Spring Training, 2010.],
  ),
  conference: (
    short: "Conference acronym 'XX",
    name: "Make sure to enter the correct conference title from your rights confirmation email",
    venue: "Woodstock, NY",
    date: "June 03–05, 2018",
  ),
  isbn: "978-1-4503-XXXX-X/2018/06",
  doi: "XXXXXXX.XXXXXXX",
  acm-year: 2018, acm-month: 6,
  copyright: "acmlicensed", copyright-year: 2018,
  short-authors: "Trovato et al.",
  authors: sample-authors,
  abstract: sample-abstract,
  ccs: sample-ccs,
  received: sample-received,
)

#sample-body(documentclass: "sigconf, language=french, language=german, language=spanish, language=english")
