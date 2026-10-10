# Release process

This document describes how to cut a release of `rules_celix` and publish the source archive asset.
It is the checklist used for each tagged release.

The project is **not yet** on the Bazel Central Registry (BCR) and does not use outbound announcement channels.
Releases are GitHub tags + release notes, plus a deterministic source archive so `git_override`-style consumers have a stable URL to pin to.

## 1. Commit the version bump

Update the module version in `MODULE.bazel`:

```python
module(
    name = "rules_celix",
    version = "<version>",  # e.g. 0.2.0
)
```

Update `docs/developing/roadmap.md` if the status or milestone table reference the version, and `docs/using/quickstart.md` if the `git_override`/`local_path_override` snippets need a new tag.
Keep the `git_override`/`local_path_override` snippets in sync with the release tag.

Run the checks from the [Contributing guide](../../CONTRIBUTING.md) before tagging:

```bash
./bazelw run @buildifier_prebuilt//:buildifier -- -r .
./bazelw test //...
```

## 2. Create the release tag

All commits must be signed off (`git commit -s`).
CI enforces this via the DCO workflow.
Push the version bump to `main`, then tag:

```bash
git tag -a v<version> -m "Release v<version>"
git push origin v<version>
```

The `v*` tag push triggers the `release` job in `.github/workflows/ci.yml` as a pre-release gate (build + test on Linux).
If it fails, fix the tree and move the tag before releasing.

## 3. Build the source archive

From the repository root, create a deterministic archive of the tag using `git archive`.
Use the `v<version>` tag name so the top-level directory matches the strip prefix that consumers (and future BCR templates) expect:

```bash
git archive --format=tar --prefix=rules_celix-v<version>/ v<version> | gzip > rules_celix-v<version>.tar.gz
```

The result must extract under `rules_celix-v<version>/`:

```bash
tar -tzf rules_celix-v<version>.tar.gz | head
```

> **Why upload a custom archive if GitHub already generates one for each tag?**
>
> GitHub's automatically generated `.zip`/`.tar.gz` are content-identical to `git archive` and are perfectly valid.
> The custom archive is uploaded anyway because it:
>
> - **Gives a stable, predictable strip prefix.** `--prefix=rules_celix-v<version>/` makes the top-level directory `rules_celix-v<version>/`.
> GitHub's generated tarballs instead root under `rules_celix-<7-char-commit-sha>/`, so an `http_archive`/`git_override` consumer's `strip_prefix` would depend on the commit hash.
> A fixed prefix matches what `.bcr/source.template.json` expects (`rules_celix-<VERSION>`).
> - **Matches the documented download URL / asset name.** `rules_celix-v<version>.tar.gz` is the filename the [quick start](../using/quickstart.md) and BCR template reference (`.../release/download/v<version>/rules_celix-v<version>.tar.gz`), letting the documented URL resolve to a real asset.
> - **Let us control the contents.** `git archive` snapshots only tracked files as of the tag and honors `.gitattributes` `export-ignore` (e.g. excluding `.github/`, CI internals, or dev-only files), and never includes `.git`, commit SHAs, or untracked/local files.
> - **Provides an authoritative, verifiable checksum.** Built deterministically from a fixed tag by a canonical command, we publish one SHA-256 consumers can verify against the asset (see section 4).
>
> Net effect: the custom archive is for a stable, documented, checksummed artifact - not for content the tag's own files don't already contain.

## 4. Record the checksum

Compute the SHA-256 of the archive.
Consumers of an `http_archive`-style download will need it.
The `.bcr/source.template.json` expects a matching integrity value if BCR publication is ever resumed:

```bash
sha256sum rules_celix-v<version>.tar.gz
```

Paste the checksum into the release notes (or a `RELEASES.md` entry) so users can check what they download.

## 5. Publish the GitHub release

- Create a release on GitHub pointing at the `v<version>` tag.
- Attach `rules_celix-v<version>.tar.gz` as the sole release asset.
- In the release body, briefly summarize the changes and include the SHA-256 of the archive.

The release notes should link to this document when the release differs from the steps above.

## Versioning and BCR

- Tags follow `vX.Y.Z` (leading `v`).
  The Bazel module version is `X.Y.Z`.
- BCR publication remains deferred to v1.0. When it is resumed, `.bcr/` templates expect:
  - `url`: `https://github.com/softyo/rules_celix/releases/download/<TAG>/rules_celix-<TAG>.tar.gz`
  - `strip_prefix`: `rules_celix-<VERSION>`

  Note the pre-existing `{TAG}` / `{VERSION}` mismatch in `.bcr/source.template.json` (`v0.1.0` vs `0.1.0`): the assets are named with the tag and the strip prefix drops the `v`.
  This is intentional and only matters for BCR, which is out of scope until v1.0.
