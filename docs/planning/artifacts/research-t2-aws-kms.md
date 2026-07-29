# Research — S3 historical retrieval and KMS permissions

Retrieved and checked 2026-07-29.

## General-purpose S3 buckets

Primary sources:

- <https://docs.aws.amazon.com/AmazonS3/latest/userguide/UsingKMSEncryption.html>
- <https://docs.aws.amazon.com/AmazonS3/latest/userguide/using-with-s3-policy-actions.html>

Durable facts:

- The general SSE-KMS guide's Permissions section says:
  - `PutObject` encryption needs `kms:GenerateDataKey`;
  - downloading an SSE-KMS object needs `kms:Decrypt`; and
  - multipart upload needs both.
- The guide's decryption workflow says S3 sends the stored encrypted data key
  to KMS in a `Decrypt` request.
- The S3 policy-action table maps `GetObject`/`GetObjectVersion` to conditional
  `kms:Decrypt` for a KMS customer-managed-key encrypted object.
- The same table maps `kms:GenerateDataKey` to upload/destination operations
  such as `PutObject`, multipart initiation/parts, and a copy destination.

## Directory buckets

Primary sources:

- <https://docs.aws.amazon.com/AmazonS3/latest/API/API_GetObject.html>
- <https://docs.aws.amazon.com/AmazonS3/latest/userguide/s3-express-UsingKMSEncryption.html>

Durable facts:

- The `GetObject` API page separates its Permissions section into
  “General purpose bucket permissions” and “Directory bucket permissions.”
- The sentence requiring both `kms:GenerateDataKey` and `kms:Decrypt` follows
  and belongs to the **Directory bucket permissions** bullet. It is not a
  general-purpose-bucket statement.
- The dedicated directory-bucket SSE-KMS guide likewise says uploading or
  downloading needs both actions.
- The `GetObject` API page also says directory buckets do not support S3
  Versioning and accept only `null` for `versionId`.

## Evaluation consequence

The earlier `current-findings.md` claim that the `GetObject` API reference
creates a general-purpose-bucket documentation conflict is not supported by
the page's actual list structure. T2's current reconciliation is accurate:

- general-purpose historical retrieval: `kms:Decrypt`;
- general-purpose upload/destination paths: `kms:GenerateDataKey`;
- directory-bucket access: both; and
- directory buckets remain outside version-history recovery.

T2 should retain its immediate-preimplementation recheck because provider
documentation and authorization behavior can change.
