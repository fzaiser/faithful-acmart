// Exhaustive format × base-font-size construction matrix.

#import "/src/formats/manuscript.typ": manuscript
#import "/src/formats/acmsmall.typ": acmsmall
#import "/src/formats/acmlarge.typ": acmlarge
#import "/src/formats/acmtog.typ": acmtog
#import "/src/formats/sigconf.typ": sigconf
#import "/src/formats/sigplan.typ": sigplan
#import "/src/formats/acmengage.typ": acmengage
#import "/src/formats/sigchi-a.typ": sigchia
#import "/src/formats/acmcp.typ": acmcp

#let formats = (
  "manuscript": manuscript,
  "acmsmall": acmsmall,
  "acmlarge": acmlarge,
  "acmtog": acmtog,
  "sigconf": sigconf,
  "sigplan": sigplan,
  "acmengage": acmengage,
  "sigchi-a": sigchia,
  "acmcp": acmcp,
)

#for (name, builder) in formats {
  for size in (8pt, 9pt, 10pt, 11pt, 12pt) {
    let cfg = builder(font-size: size)
    assert.eq(cfg.name, name)
    assert(cfg.font-size > 0pt and cfg.baselineskip > cfg.font-size,
      message: name + " " + repr(size) + " has an invalid type ladder")
    assert(cfg.margin.top >= 0pt and cfg.margin.bottom >= 0pt,
      message: name + " " + repr(size) + " has invalid geometry")
  }
}

// The obsolete public options `siggraph` and `sigchi` are aliases: the option
// resolver maps them to the sigconf builder (matching the bundled LaTeX class).
// The compile-only siggraph-test / sigchi-test smokes prove the full pipeline
// accepts them; these asserts pin the mapping itself.
#import "/src/parts/options.typ": formats as format-table
#assert.eq(format-table.at("siggraph"), format-table.at("sigconf"),
  message: "siggraph must resolve to the sigconf config")
#assert.eq(format-table.at("sigchi"), format-table.at("sigconf"),
  message: "sigchi must resolve to the sigconf config")
#assert.eq(format-table.at("siggraph")().name, "sigconf")
#assert.eq(format-table.at("sigchi")().name, "sigconf")
