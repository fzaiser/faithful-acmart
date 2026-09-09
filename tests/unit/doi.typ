#import "/src/parts/doi.typ": normalize-doi

// A bare identifier passes through; only whitespace around it is dropped.
#assert.eq(normalize-doi("10.1145/3597503"), "10.1145/3597503")
#assert.eq(normalize-doi("  10.1145/3597503  "), "10.1145/3597503")

// Scheme and host match case-insensitively, and the identifier keeps its own case.
#assert.eq(normalize-doi("https://doi.org/10.1145/Example"), "10.1145/Example")
#assert.eq(normalize-doi("http://doi.org/10.1145/Example"), "10.1145/Example")
#assert.eq(normalize-doi("HTTPS://DOI.ORG/10.1145/Example"), "10.1145/Example")
#assert.eq(normalize-doi("https://dx.doi.org/10.1145/Example"), "10.1145/Example")
#assert.eq(normalize-doi("http://DX.Doi.Org/10.1145/Example"), "10.1145/Example")

// Only one prefix is stripped, so a doubled resolver still reports the inner URL.
#assert.eq(normalize-doi("https://doi.org/https://doi.org/10.1000/x"), "https://doi.org/10.1000/x")

// Unrelated hosts, other schemes, and DOI suffix syntax are left alone.
#assert.eq(normalize-doi("https://example.org/10.1145/Example"), "https://example.org/10.1145/Example")
#assert.eq(normalize-doi("https://doi.org.evil.test/10.1145/Example"), "https://doi.org.evil.test/10.1145/Example")
#assert.eq(normalize-doi("ftp://doi.org/10.1145/Example"), "ftp://doi.org/10.1145/Example")
#assert.eq(normalize-doi("doi:10.1145/Example"), "doi:10.1145/Example")
#assert.eq(normalize-doi("10.1145/a%2Fb(c)"), "10.1145/a%2Fb(c)")
