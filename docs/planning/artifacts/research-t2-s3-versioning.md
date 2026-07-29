# Research — S3 Versioning recovery prerequisites

Retrieved and checked 2026-07-29.

## Versioning states and history

Primary source:

- <https://docs.aws.amazon.com/AmazonS3/latest/userguide/Versioning.html>

Durable facts:

- S3 Versioning is disabled by default and must be explicitly enabled.
- General-purpose buckets can be never-enabled, versioning-enabled, or
  versioning-suspended.
- After first enablement, a bucket cannot return to the never-enabled state; it
  can only be suspended.
- Enabling versioning affects future writes. Existing objects do not
  retroactively receive unique historical versions; pre-enable objects use the
  `null` version ID until later modification.
- Suspending versioning does not alter existing retained versions.
- Lifecycle configuration can expire noncurrent versions, so prior enablement
  does not guarantee the desired version still exists.

## Bucket status API

Primary sources:

- <https://docs.aws.amazon.com/AmazonS3/latest/API/API_GetBucketVersioning.html>
- <https://docs.aws.amazon.com/cli/latest/reference/s3api/get-bucket-versioning.html>

Durable facts:

- `GetBucketVersioning` reports `Enabled`, `Suspended`, or an empty
  configuration for never-enabled buckets.
- AWS states that retrieving bucket versioning state requires the bucket owner.
- The operation is unsupported for directory buckets.

## Design consequence

T2 should explain prior enablement and retained-version requirements in prose
but should not make `get-bucket-versioning` a mandatory recovery preflight. A
delegated principal with list/get-version permission may not be the bucket
owner. Exact-key `list-object-versions` results are the recovery-relevant
evidence.
