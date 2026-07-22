# Security Policy

## Reporting a vulnerability

Please **do not** open a public GitHub issue for security vulnerabilities.

Instead, use GitHub's private vulnerability reporting: go to the
[Security tab](https://github.com/chethankumblekar/tenantforge/security)
of this repo and click **Report a vulnerability**. If that's not
available, email chethankumblekar@gmail.com with details.

Include:

- What component is affected (Terraform module, `sample-service`, CI
  pipeline, a Kubernetes manifest, etc.)
- Steps to reproduce, or a proof of concept
- The potential impact as you see it

## Scope and expectations

This is a reference/demo platform (see
[REQUIREMENTS.md](REQUIREMENTS.md)'s non-goals) — it is not running a
production workload with real user data. That said, the supply-chain and
in-cluster security controls it implements (image signing, SBOM
attestation, NetworkPolicy, OPA/Gatekeeper admission policy, Workload
Identity Federation) are meant to reflect real practice, so a bypass of
any of those is a legitimate finding worth reporting.

There's no bug bounty — this is a single-maintainer project. Reports will
be acknowledged and a fix or mitigation will be prioritized based on
severity.

## Supported versions

This project doesn't follow semantic versioning or maintain release
branches; only the `main` branch is supported.
