## Why
`jef push` checks out and pushes every repository that has the branch, even when origin already has everything. Pushing should only happen when there is something to push.

## What Changes
- Before any checkout, ask origin for the branch tip (`git ls-remote`) and compare it with the local tip.
- Up to date or behind origin: print "Nothing to push" (or "Nothing to push (behind origin)"), skip the repository without checkout or push; an up-to-date branch without upstream gets tracking set.
- Ahead: print "Pushing N commits" and push; new, diverged or unknown-tip branches are pushed and git decides.
- Unreachable origin: "Could not reach origin", repository fails.
- Dry run applies the same check read-only.

## Impact
- Spec: branch-push. Code: commands/jef-push.sh. Docs: README.md.
