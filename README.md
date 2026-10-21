# topdirs

The biggest folders on your system, with full paths — in one command, without
lying to you.

**English** · [Português (BR)](README.pt-BR.md)

```
$ sudo topdirs
> scanning / (depth 2)

#         SIZE    %
 1    43.6GiB  46.9%  ██████████············ /usr
 2    31.7GiB  34.1%  ███████··············· /home
 3    31.7GiB  34.1%  ███████··············· /home/spingat
 4    18.8GiB  20.1%  ████·················· /usr/lib
 5    18.0GiB  19.3%  ████·················· /usr/share
 6    14.5GiB  15.5%  ███··················· /var
 7    13.3GiB  14.2%  ███··················· /var/lib
 8     5.1GiB   5.4%  █····················· /usr/bin
 9   936.0MiB   0.9%  █····················· /var/log

311 folders · 92.9GiB scanned · 11s
Single filesystem (-x). Use -X to include other mounts.
```

*(Output is localized in Portuguese; an English locale is on the TODO list.)*

## Install

One file, no dependencies beyond `coreutils`. `jq` is only needed for
`--json`, and `numfmt` falls back to `awk`.

```sh
curl -fsSL https://raw.githubusercontent.com/glearflame/topdirs/main/topdirs \
  -o ~/.local/bin/topdirs
chmod +x ~/.local/bin/topdirs
```

Or clone the repo (installer included):

```sh
git clone https://github.com/glearflame/topdirs.git
cd topdirs
./install.sh                 # ~/.local/bin (or /usr/local/bin as root)
sudo ./install.sh            # so "sudo topdirs" works
```

Works on any Linux with Bash 4+ and GNU coreutils (tested on Debian/Kali).
Not pure POSIX: it uses `sort -z`, `du -0` and `read -d`.

### Making `sudo` work

`~/.local/bin` is not in sudo's `PATH` (it uses `secure_path`). If
`sudo topdirs` says `command not found`, install into `/usr/local/bin`:

```sh
sudo install -m755 topdirs /usr/local/bin/topdirs
```

If that still fails, check `sudo printenv PATH`. The Debian default includes
`/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin`; if yours was
trimmed, fix `Defaults secure_path` (or use `sudo env "PATH=$PATH" topdirs`).

## Usage

```sh
topdirs                          # top 20 of /, depth 2
sudo topdirs                     # complete scan (recommended)
topdirs /home -n 10              # top 10 inside /home
topdirs -d 1                     # totals per top-level directory
topdirs -d 3 --no-nested         # no parent+child in the same ranking
topdirs -X -d 1                  # include /mnt, /media, external disks
topdirs -t 1G -d 4 /var          # only entries above 1 GiB in /var
topdirs --json | jq -r '.[].path'
topdirs -g                       # nice 19 + ionice idle: don't hammer the disk
```

### Options

| Option | Effect |
| --- | --- |
| `-n, --count N` | how many results (default: 20) |
| `-d, --depth N` | scan depth (default: 2) |
| `-a, --all` | include files, not just folders |
| `-X, --cross-mounts` | cross into other filesystems (default: `du -x`) |
| `-e, --exclude PATTERN` | exclude a path (repeatable; default: `/proc /sys /dev /run`) |
| `-t, --threshold SIZE` | only entries above SIZE (`500M`, `2G`) |
| `--no-nested` | hide a folder that is inside another listed folder |
| `--df-check` | compare the scanned total against `df` used |
| `--apparent-size` | logical size instead of allocated blocks |
| `--json` | JSON output |
| `--no-bar`, `--no-color`, `--ascii` | presentation |
| `-g, --gentle` | `nice 19` + `ionice idle` |
| `-q, --quiet` | table only |
| `-h, --help`, `-V, --version` | help and version |

## Why not `du -h | sort -h | head -20`

Because that pipeline gets real-world cases wrong:

| Problem | What happens | What `topdirs` does |
| --- | --- | --- |
| Newline or tab in a path | the line breaks, the path becomes garbage in the ranking | NUL pipeline (`du -0`, `sort -z`) |
| `pt_BR` locale | `sort -h` compares `1,2G` as text | `LC_ALL=C` + numeric sort in KiB |
| `/proc`, `/sys` | `/proc/kcore` shows up with an absurd size | excluded by default |
| Hardlinks | two scripts count the same file twice | a single `du` invocation (counted once) |
| Unreadable directory | error goes to stderr, list looks complete | explicit warning with a count |
| USB/NFS mount | the scan hangs for minutes | `du -x` by default |

## What the number means

By default: **allocated disk space** (blocks), not logical size. A 100 GiB VM
image that occupies 4 GiB shows as 4 GiB — that's what `df` sees. Use
`--apparent-size` for logical size.

Hardlinks are counted **once**, so the second folder of a file with two links
may show `0`. That is intentional.

### Proving the measurement

`--df-check` compares the scanned total against `df` used:

```
$ sudo topdirs -n 3 --no-bar --df-check /
df of filesystem: 92.9GiB used · scanned: 92.9GiB · difference: 4.2MiB (0%)
```

With root the difference stays below 0.1% — proof the measurement is right.
Without root:

```
df of filesystem: 92.9GiB used · scanned: 92.5GiB · difference: 455.3MiB (0%)
WARNING: 65 directories unreadable — total underestimated.
```

The difference is exactly the size of the hole in the list.

## Known limitations

- **Bind mounts.** A bind mount inherits the same `st_dev`, so `du -x` walks
  into it and may double count. Detecting that requires parsing mountinfo.
- **Deleted-but-open files** do not appear in `du` (no directory entry).
  `--df-check` exposes that gap when compared to `df`.
- **Layered storage** (btrfs, ZFS, Docker overlay) has no well-defined
  "folder size"; numbers are whatever is allocated there.
- **`--no-nested`** hides where the weight sits inside the ancestor. That is
  why it is opt-in.

## License

MIT. See [LICENSE](LICENSE).
