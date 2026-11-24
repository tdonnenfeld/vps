# Private Palma runner

Use only the private phd-experiments repository. Restrict write access and run only reviewed workflows; never run untrusted PR code on this runner. The service runs as phd-runner with CPUQuota=400%, MemoryMax=5G, MemorySwapMax=0 and restricted filesystem writes. This is host systemd isolation, not a container or a complete security boundary. No disk quota or outbound network isolation is enforced yet.

After deployment, visit the private repository Settings > Actions > Runners > New self-hosted runner, select Linux x64, and use its current download and checksum instructions in /var/lib/phd-runner/actions-runner as phd-runner. Install OS dependencies as administrator if required. Configure using the repository URL, short-lived registration token, name palma-phd and label palma-phd; use --work /opt/services/phd-data/workspaces. Never commit the token. Do not use svc.sh install because the Ansible-managed service uses runsvc.sh directly.

Start with sudo systemctl enable --now phd-runner.service, inspect sudo journalctl -u phd-runner.service -n 50, then manually launch the smoke test from main in the private repository. No cluster credentials or Docker group membership. Check repository permissions and the actual system account before running jobs.
