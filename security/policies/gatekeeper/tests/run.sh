#!/usr/bin/env bash
# Unit-tests the Rego embedded in each ConstraintTemplate CRD, without a
# cluster or Gatekeeper itself installed. The CRD YAML is the single
# source of truth (Gatekeeper only accepts rego inline in
# spec.targets[].rego, not a file reference), so this extracts each
# template's rego into a real .rego file, drops it alongside the
# hand-written *_test.rego files here, and runs `opa test` — a real
# regression check for the class of bug ADR-0004's sibling fix caught
# manually (see required_resources_test.rego).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

for f in ../constrainttemplates/*.yaml; do
  name="$(basename "$f" .yaml)"
  python3 -c "
import sys, yaml
with open('$f') as fh:
    doc = yaml.safe_load(fh)
print(doc['spec']['targets'][0]['rego'])
" > "$workdir/$name.rego"
done

cp ./*_test.rego "$workdir/"

opa test --v0-compatible -v "$workdir"
