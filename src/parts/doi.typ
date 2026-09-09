// Normalize DOI input that already carries a resolver URL.

// The metadata and BibLaTeX DOI formats both prepend https://doi.org/, which doubles
// the resolver when the field already holds one.
#let normalize-doi(d) = {
  let t = d.trim()
  let m = t.match(regex("(?i)^https?://(dx\\.)?doi\\.org/"))
  if m == none { t } else { t.slice(m.end) }
}
