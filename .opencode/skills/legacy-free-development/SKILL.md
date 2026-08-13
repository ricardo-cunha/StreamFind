---
name: legacy-free-development
description: Use for refactoring, migrations, architecture changes, package moves, or interface replacement in StreamFind. Enforce the target architecture directly and prevent legacy fallbacks, shims, duplicate paths, and unapproved migration helpers.
---

# Legacy-Free Development

During the active StreamFind refactor, the codebase must move toward the target architecture without accumulating legacy scaffolding.

## Required Rules

- Do not create a fallback path to legacy implementation code.
- Do not add compatibility shims, forwarding modules/packages, duplicate source trees, dual execution paths, transitional adapters, or migration helpers.
- Do not preserve an old API or build path because the replacement is incomplete. Implement the replacement at its intended boundary.
- Treat relocations as atomic: after a move, there must be one owning implementation path.
- Do not add feature flags that select old versus new behaviour.

## Deferred Boundaries

Keep `bindings/r` functional as it is during the active C++/Python and Rust implementation work. Do not refactor it, redirect it, or add R migration helpers until the C++-backed Python distribution and the Rust domain implementations are complete.

Likewise, keep `integrations/cf-streamfind` at its current boundary until that end-stage alignment work begins.

A build or packaging repair is allowed only when it preserves existing behaviour and does not create a new compatibility layer.

## When Compatibility Is Truly Required

For a released, user-facing transition that genuinely requires compatibility or data migration:

1. Stop the routine refactor.
2. Request an explicit, separately scoped decision.
3. Document the supported versions, removal date, and tests.
4. Isolate the transition code from the target implementation.
5. Remove it when the approved transition window ends.

Never introduce such code speculatively.
