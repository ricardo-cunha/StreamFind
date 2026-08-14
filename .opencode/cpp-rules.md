# C++ Project Rules

- Do not create anonymous namespaces (`namespace {}`) in project C++ code.
- Use an explicit named internal namespace such as `streamfind::detail` for
  non-public helpers, or use a file-local `static` function where appropriate.
- This rule applies to `core/` and project-owned C++ code. Do not rewrite
  third-party or vendored source under `core/vendor/`.
