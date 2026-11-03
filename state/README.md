# Desired release identity by environment

`dev.json`, `stage.json` and `prod.json` track **desired release identity**,
not Kubernetes credentials or a claim that a live cluster has been reconciled.
They intentionally start with `release: null` because nothing has been
published or deployed through the new release pipeline yet.

Workflow:

1. Dispatch `Publish immutable OCI release` on green `main` and download
   the `immutable-release` artifact.
2. Run `python3 delivery/state.py record-dev release.json` and propose the
   resulting `state/dev.json` change in a reviewed PR.
3. Deploy/verify the selected exact digest in a controlled environment
   (not automated here); investigate failures before any promotion.
4. Run `python3 delivery/state.py promote --source state/dev.json --target
   state/stage.json` **in a later PR**. Stage must reference a release already
   present in the prior environment's committed history.
5. After stage verification, promote `stage -> prod` analogously.

`python3 delivery/state.py verify --history-ref origin/main` ensures stage
and prod cannot introduce a version that never appeared in the preceding
environment's Git history. It does not substitute for reviewer approval,
runtime health checks, admission policy or cryptographic signature verification.

Promotion copies the **same six OCI digests and source SHA**. It never rebuilds
or substitutes tags. A PR that changes stage/prod in the same commit as
introducing a new dev release fails the history gate.

After a reviewed merge of release state, an authorized operator may use
[delivery/rollout.py](../delivery/rollout.py) to plan or explicitly apply the
exact signed image set. It does not build images, mutate credentials or deploy
stateful infrastructure. Production cluster action remains opt-in.
