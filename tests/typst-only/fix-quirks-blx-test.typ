#import "/src/lib.typ": *
#import "_fix-quirks-blx.typ": blx-opts, blx-body

#show: acmart.with(..blx-opts, cite-style: "author-year", fix-quirks: true)

#blx-body
