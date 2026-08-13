# Legacy-Free Development Rule

During active refactoring, implement the target architecture directly.

- Do not add a legacy fallback, compatibility shim, forwarding module/package, dual execution path, migration helper, feature flag that preserves legacy behaviour, or duplicate legacy copy.
- Do not keep an old interface alive merely because the target implementation is incomplete. Complete the target boundary instead.
- Keep a source move atomic: after a completed relocation, there is one owning implementation path.
- Treat `bindings/r` as a preserved, functional package during the current development phase. Do not refactor it, add transition helpers, or redirect it to the new backend until the C++/Python and Rust domain implementations are complete.
- Treat `integrations/cf-streamfind` the same way: defer public-Python integration work until the end-state C++/Python and Rust domain implementations are complete.
- Repairing an existing package or build break is allowed only when it preserves the current behavior without adding a new compatibility layer.
- If compatibility or data migration is genuinely required for a released user-facing version, stop and request an explicit, separately scoped migration decision. Keep that work isolated and remove it after the approved transition window.
