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
