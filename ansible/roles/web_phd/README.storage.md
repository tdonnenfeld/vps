# PhD experiment storage

The web_phd role provisions /opt/services/phd-data with separate datasets, results and workspaces directories. The dedicated phd-runner account is password-locked and has no Docker or sudo access. The dataset directory is owned by the administrator and group-readable by phd-runner; results and workspaces are owned by phd-runner. The root is restricted to root and phd-data group members. Directory provisioning is skipped during check mode because the group may not exist yet.

Uploads staged in ~/subsampled are not touched by Ansible. After transfer completes and checksums are verified, the administrator can copy the validated variants using sudo rsync -rt --chown=theo:phd-data --chmod=D2750,F0640 SOURCE/ /opt/services/phd-data/datasets/. Inspect the source and reject symlinks first; do not copy full datasets or unvalidated files. Keep the staging copy until destination checksums have been verified. Do not overwrite existing registered variants.

No runner is registered, no web container mounts these directories, and no cluster connection is configured. Resource limits and execution isolation are follow-up work.
