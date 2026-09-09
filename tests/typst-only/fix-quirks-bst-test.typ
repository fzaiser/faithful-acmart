#import "/src/lib.typ": *
#import "_fix-quirks-bst.typ": bst-opts, bst-body

#show: acmart.with(..bst-opts, fix-quirks: true)

#bst-body
