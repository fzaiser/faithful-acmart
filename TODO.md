# TODO

- Replace `tools/test.py overlay`'s Ghostscript+`qpdf` pipeline with `pikepdf`:
  rewrite all colour operators, including spot/ICC `setcolor`, and compose page
  XObjects with `/BM /Multiply` plus alpha so aligned ink renders dark.
