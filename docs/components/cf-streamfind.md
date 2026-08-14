# Cogniflow integration (deferred)

`integrations/cf-streamfind` is the relocated Cogniflow integration boundary.
It is intentionally not expected to build during the current phase: the
Cogniflow dependencies are not available and its native implementation will be
refactored in this location.

The package builds the Cogniflow native step library from the shared streamfind
C++ core and the Cogniflow adapter under
`integrations/cf-streamfind/src/cf_streamfind/cpp/`. It is exposed to
Cogniflow through the `cogniflow.steps` entry-point mechanism rather than as a
standalone end-user Python API.

Work is deferred until the public C++/Python path is complete, after which
Cogniflow will consume the installed public `streamfind` Python package and
the canonical semantic catalogue.
