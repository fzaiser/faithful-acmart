// Exhaustive copyright-mode and Creative Commons choice coverage.

#import "/src/parts/copyright.typ": permission-text, copyright-owner, cc-statement

#let modes = (
  "none", "acmcopyright", "acmlicensed", "rightsretained", "usgov", "usgovmixed",
  "cagov", "cagovmixed", "licensedusgovmixed", "licensedcagov",
  "licensedcagovmixed", "othergov", "licensedothergov", "iw3c2w3", "iw3c2w3g",
)

#for mode in modes {
  let permission = permission-text(mode)
  let owner = copyright-owner(mode)
  if mode == "none" {
    assert.eq(permission, none)
    assert.eq(owner, none)
  } else {
    assert.eq(type(permission), content, message: mode + " has no permission content")
    // usgov intentionally has no copyright-owner line.
    assert(mode == "usgov" or type(owner) == content,
      message: mode + " has no copyright owner content")
  }
}

#for license in ("by", "by-sa", "by-nd", "by-nc", "by-nc-sa", "by-nc-nd") {
  for version in ("3.0", "4.0") {
    assert.eq(type(cc-statement(license, version)), content,
      message: license + " " + version + " did not render")
  }
}
#assert.eq(type(cc-statement("zero", "1.0")), content)
#assert.eq(type(permission-text("cc", cc-type: "by", cc-version: "4.0")), content)
#assert.eq(type(copyright-owner("cc")), content)
