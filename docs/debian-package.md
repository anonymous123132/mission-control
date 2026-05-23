# Debian package install

Build a local `.deb` package:

```bash
pnpm install
pnpm build:deb
```

Output package path:

```bash
dist/mission-control_<version>_<arch>.deb
```

Install with apt:

```bash
sudo apt install ./dist/mission-control_<version>_<arch>.deb
```

During install, `debconf` asks for the Mission Control port (default `3000`).
The selected port is written to `/etc/default/mission-control`.

Service commands:

```bash
sudo systemctl status mission-control
sudo systemctl restart mission-control
journalctl -u mission-control -f
```

Open the app:

```text
http://localhost:<port>/setup
```
