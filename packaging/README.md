# Native parser package and independent replay

The runtime package contains the unchanged compiled Chez parser program, its
Idriç support library, the pinned threaded Chez 10.4.1 executable and boot
files, every ELF provider observed for those objects (including the loader),
and complete ICKY, Idriç and Chez source snapshots. No unmaterialized source
gitlinks are admitted. Every runtime/source/provenance file has a SHA-256 and
mode in the canonical `material.tsv`. The inner tar preserves modes even when
GitHub's outer artifact ZIP does not.

The compiler-generated launchers and complete test/parser app directories
remain in the producer receipt. They are evidence of the source build, not
the package entrypoint: the generated program's shebang names the producer's
absolute Chez path. `launch.grease` instead executes those unchanged parser
bytes through the archived ELF loader, archived Chez executable, boot files
and support library. It takes an absolute package root, `parser`, and CLI
arguments. The parser package does not require a compiler or source checkout.
The original 77 assertions and five type refusals remain producer checks;
the consumer supplies its own runtime oracle.

Grease is the declared **launch and verification harness**, separate from
the parser's **runtime material** and the source compiler's **bootstrap tools**.
Its current pinned native implementation has an applet-name requirement.
The workflow's small acquisition adapter installs the verified artifact,
adds a host-specific shebang to the canonical Grease
`grease-entrypoint.grease`, and names the resulting command `grease`.
Only this initial acquisition uses GitHub's fixed shell interface; all new
packaging, material-validation, replay and mutation logic runs through Grease.
The foreign runtime is pinned to Grease owner source
`9a874c4e082d26f21b2cc807b5553e7e19d5f590`, inherited source
`5651cf97a1b5042f24f14112a7ade9a1518eb0bc`, artifact `11419782646`,
native executable SHA-256
`7e31cd05b7a9d8fb2a4a9e003a7f3fcb0159138506d17f0fb28da8cbe22aa85c`.
If that owner artifact expires or is removed, acquisition fails; it does not
select another shell. A maintained replacement requires refreshed owner
qualification and reviewed pins.

`replay.grease` receives the source checkout (oracle only), original archive,
expected archive digest, pinned ai-ci checkout, explicit Grease command and a
new workspace. It checks the archive before extracting, rejects unsafe paths,
links/special nodes and duplicate members, relocates it to an unrelated
directory, and executes all three identities plus v1/v2/v3 positive and v3
malformed/missing-input controls. It checks source snapshots against the
independent checkout and locked compiler/runtime source archive hashes.

The replay repeats with poisoned PATH and attacks separate copies: missing
compiled app, support library, boot file or libc provider, a no-op program,
forged inventory, old-checkout launcher, wrong compiler identity, changed
tool source archive, wrong repository and a stale submodule declaration.
Four archive controls reject unsafe paths, duplicate members, links and wrong
archive digests. Recomputed manifests do not waive required material or
semantic behavior. The package is checked again after execution to ensure it
was not filled in or modified by the verifier.

Qualification is bounded to Linux x86_64 and this Chez lane. A complete host
package does not establish ICK frontend consumption, Flexible Pipes admission,
Cat Food activation, Android execution or physical behavior. Those obligations
remain on [Flexible Pipes issue #71](https://github.com/isomorphisms/flexible-pipes/issues/71).
