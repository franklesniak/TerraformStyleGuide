# Research — HCP token and inherited Bash xtrace

Retrieved and checked 2026-07-29.

## Bash xtrace

Primary source:

- <https://www.gnu.org/software/bash/manual/html_node/The-Set-Builtin.html>

Durable facts:

- `set -x` causes Bash to print simple commands and their arguments after
  expansion and before execution.
- `set +x` disables that behavior.
- A parent shell's enabled xtrace state is active inside a subshell until the
  subshell disables it.
- A `set +x` performed inside `( ... )` does not disable tracing in the parent
  after the subshell exits.

## Curl configuration boundary

Primary source:

- <https://curl.se/docs/manpage.html>

Durable facts:

- `--config -` reads curl configuration from standard input.
- `-q`/`--disable` must be the first command-line parameter to prevent curl
  from reading its default user configuration.
- Keeping the Authorization header in stdin configuration prevents it from
  appearing in curl's ordinary command-line argument list.
- This protection is independent of shell xtrace: Bash can expose the expanded
  here-document or earlier token assignment before curl starts.

## Synthetic reproduction

Environment: Git for Windows Bash 5.2.21, synthetic value only.

Without an early `set +x`:

```text
+ umask 077
+ TFC_TOKEN=SYNTHETIC-TRACE-MARKER
+ :
```

With `set +x` as the first subshell command:

```text
+ set +x
```

Both commands returned zero. The second trace contained no sentinel. This test
used no real token and made no network request.

## Design consequence

The HCP example should retain stdin curl configuration and add `set +x` as the
first command inside its existing subshell. Validation should enter with
xtrace enabled, use a synthetic sentinel, capture both output streams, and
assert that the sentinel is absent.
