# Research — GitHub Actions release pins

Retrieved and checked 2026-07-29.

## Current selected releases

Primary release and commit sources:

- checkout v7.0.1:
  - <https://github.com/actions/checkout/releases/tag/v7.0.1>
  - <https://github.com/actions/checkout/commit/3d3c42e5aac5ba805825da76410c181273ba90b1>
- setup-node v7.0.0:
  - <https://github.com/actions/setup-node/releases/tag/v7.0.0>
  - <https://github.com/actions/setup-node/commit/820762786026740c76f36085b0efc47a31fe5020>
- upload-artifact v7.0.1:
  - <https://github.com/actions/upload-artifact/releases/tag/v7.0.1>
- download-artifact v8.0.1:
  - <https://github.com/actions/download-artifact/releases/tag/v8.0.1>

Verified pairs used by T1:

```text
actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
actions/setup-node@820762786026740c76f36085b0efc47a31fe5020 # v7.0.0
actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a # v7.0.1
actions/download-artifact@3e5f45b2cfb9172054b4087a40e8e0b5a5461e7c # v8.0.1
```

The checkout release page reports v7.0.1 on July 20 and the setup-node release
page reports v7.0.0 on July 14, both before the issue's 2026-07-29 “as of” date.

## Compatibility facts to preserve

Primary sources:

- <https://github.com/actions/checkout/blob/v7.0.1/README.md>
- <https://github.com/actions/setup-node/blob/v7.0.0/README.md>

Durable facts:

- Checkout v7 adds safer fork handling for `pull_request_target` and
  `workflow_run`, moves to ESM, and updates dependencies.
- Checkout v7 retains the v6 credential-security behavior: persisted
  credentials are stored below `RUNNER_TEMP`; ordinary authenticated Git
  commands continue to work, subject to documented runner requirements.
- Checkout uses the Node 24 action runtime and documents a minimum runner for
  that runtime.
- Setup-node v7 moves to ESM and updates dependencies. Its inputs, runtime,
  caching behavior, and runner requirement still need workflow-specific
  verification immediately before implementation.

## Governance consequence

T1 should use these exact full SHAs as the dated baseline, reverify them
immediately before implementation, retain review-only Dependabot, and fall back
to v6 only with a concrete documented incompatibility and an “approved
ceiling” label.
