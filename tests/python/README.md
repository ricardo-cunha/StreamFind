Python package and CogniFlow step tests have not been rewritten yet for the
current `cf-streamfind` contract.

The previous scaffold tests from the playground package were removed because
they do not validate the current `projectRef` input shape or the
`sf_nta_find_features` step behavior.

Future tests should cover at least:

- local package install and wheel install behavior
- `steps.nq` packaging and signature-generation expectations
- `projectRef` JSON input validation
- `sf_nta_find_features` step execution against a prepared streamfind project
