# setup-specscore

Install a released [SpecScore CLI](https://github.com/specscore/specscore-cli) binary on a GitHub Actions runner. The action installs only; run checks in a separate step. Go is not required.

```yaml
steps:
  - uses: actions/checkout@v4
  - uses: specscore/setup-specscore@624a223677e2171e7516874c3a6bb488b94a0131 # v1
    with:
      version: v0.55.0
  - run: specscore spec lint
```

`version` is required and must be an exact release tag. The `version` output contains that tag. Linux and macOS support amd64 and arm64; Windows supports amd64. Unsupported platforms fail explicitly.

The downloaded archive is verified against the release checksum manifest before extraction. A manifest from the same release detects corruption but cannot protect against replacement of both the archive and manifest. To verify against an independently obtained archive digest, pass `expected-sha256` for the specific OS and architecture; a mismatch fails the step.
