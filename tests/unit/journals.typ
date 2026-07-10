// Direct unit tests for the ACM journal table and its class-option side effects.

#import "/src/parts/journals.typ": lookup-journal

#let pacmnet = lookup-journal("PACMNET")
#assert.eq(pacmnet.name, "Proceedings of the ACM on Networking")
#assert.eq(pacmnet.short, "Proc. ACM Netw.")
#assert.eq(pacmnet.issn, "2834-5509")

// These are the six journal choices that set \if@ACM@screen in acmart.dtx.
#for code in ("IMWUT", "PACMCGIT", "PACMHCI", "PACMPL", "PACMSE", "POMACS") {
  assert.eq(lookup-journal(code).screen, true, message: code + " must force screen mode")
}
#for code in ("JACM", "PACMMOD", "PACMNET", "TOG") {
  assert.eq(lookup-journal(code).screen, false, message: code + " must retain print-mode links")
}

#assert.eq(lookup-journal(none),
  (name: none, short: none, issn: "XXXX-XXXX", screen: false))
