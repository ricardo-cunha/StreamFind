# streamfind

The repository is being migrated to a multi-interface layout. The preserved R
package is at `bindings/r`; its package root is `bindings/r`, not the
repository root. The Cogniflow integration is at
`integrations/cf-streamfind` and is temporarily non-buildable until its
dependencies and implementation boundary are refactored.

For R development, run package commands from `bindings/r`, for example:

```text
R CMD check bindings/r
R CMD build bindings/r
```
