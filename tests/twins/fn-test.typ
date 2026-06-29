#import "/src/lib.typ": acmart
#show: acmart.with(format: "acmsmall")

= Footnotes and Code
This paragraph has a footnote#footnote[This is the footnote text, set in footnotesize with a short rule above it.] and some inline code like `printf("hello")` embedded in the text. A second footnote#footnote[Another footnote to check numbering and spacing.] follows.

```
def hello(name):
    return "Hello, " + name
```
