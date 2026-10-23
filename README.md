# topdirs

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Shell: Bash 4+](https://img.shields.io/badge/shell-bash%204%2B-4EAA25?logo=gnubash&logoColor=white)](#requirements)
[![Platform: Linux](https://img.shields.io/badge/platform-Linux-lightgrey?logo=linux&logoColor=black)](#requirements)

The biggest folders on your system, with full paths — in one command, without
lying to you.

[Português (BR)](README.pt-BR.md) · **English**

```
$ sudo topdirs -n 10
> varrendo / (profundidade 2)

#       TAMANHO      %
 1    43.6GiB  46.4%  ██████████············ /usr
 2    32.4GiB  34.4%  ███████··············· /home
 3    32.4GiB  34.4%  ███████··············· /home/spingat
 4    18.8GiB  19.9%  ████·················· /usr/lib
 5    18.0GiB  19.1%  ████·················· /usr/share
 6    14.8GiB  15.7%  ███··················· /var
 7    13.3GiB  14.1%  ███··················· /var/lib
 8     5.1GiB   5.4%  █····················· /usr/bin
 9     1.3GiB   1.2%  █····················· /var/log
10   451.8MiB   0.4%  █····················· /boot

312 pasta(s) · total varrido 94.0GiB · 50s
Filesystem único (-x). Use -X para incluir outros mounts.
```

*(Real output on Kali/Debian with ext4. Percent is each folder's share of the
scanned total, so parent and child can add up to more than 100%.)*

One Bash script, one file, no dependencies beyond `coreutils`. `jq` is only
needed for `--json`. The UI strings are currently in Portuguese; the data
(`--json`) is locale-neutral.

---

## The problem: `du -h | sort -h | head`

That pipeline does not answer "which are the biggest folders". It answers
"which are the **smallest**", because `sort -h` orders ascending and `head`
takes the beginning. It also breaks on paths containing a newline.

Real test on a demo tree with 4 KiB, 2 MiB, 3 MiB, 5 MiB (hardlink) and 40 MiB:

```console
$ du -h -d1 /tmp/opencode/demo | sort -h | head -20
0	/tmp/opencode/demo/linkA
4,0K	/tmp/opencode/demo/pequena
2,0M	/tmp/opencode/demo/nome
quebrado
3,0M	/tmp/opencode/demo/media
5,0M	/tmp/opencode/demo/linkB
40M	/tmp/opencode/demo/grande
51M	/tmp/opencode/demo
```

Three things are wrong:

1. **The smallest folders come first.** The 40 MiB folder is on line six; a
   `head -5` would never show it.
2. **The newline in a folder name broke the line** (`.../nome` and `quebrado`),
   and the second line has no size.
3. **Human units have one decimal place and mixed suffixes.** Comparing `4,0K`
   against `2,0M` happens to work with GNU `sort -h`; comparing integers in KiB
   always works.

And the cases that do not show up in that example:

```console
$ for d in linkA linkB; do du -sh "$d"; done
5,0M	linkA
5,0M	linkB          # same inode counted twice

$ du --apparent-size -h --max-depth=0 /proc/kcore
128T	/proc/kcore     # absurd "logical" size, not allocated space
```

The same tree through `topdirs`:

```console
$ topdirs /tmp/opencode/demo --no-color
> varrendo /tmp/opencode/demo (profundidade 2)

#       TAMANHO      %
 1    40.0MiB  79.9%  █████████████████····· /tmp/opencode/demo/grande
 2     5.0MiB   9.9%  ██···················· /tmp/opencode/demo/linkB
 3     3.0MiB   5.9%  █····················· /tmp/opencode/demo/media
 4     2.0MiB   3.9%  █····················· /tmp/opencode/demo/nome\nquebrado
 5     4.0KiB   0.0%  █····················· /tmp/opencode/demo/pequena
 6       0.0B   0.0%  ······················ /tmp/opencode/demo/linkA

6 pasta(s) · total varrido 50.1MiB · 0s
Filesystem único (-x). Use -X para incluir outros mounts.
```

The newline is **escaped for display** (`\n`) but stays intact in JSON. The
hardlink counts once: `linkA` shows `0.0B` because the inode was already
counted under `linkB` — that is the real disk usage `df` sees.

### What `topdirs` does differently

| Trap | Naive pipeline | `topdirs` |
| --- | --- | --- |
| `sort -h \| head` | shows the **smallest** folders | numeric KiB sort, takes the biggest |
| Newline/tab in a path | breaks the line, corrupts the ranking | NUL pipeline (`du -0`, `sort -z`) |
| Human units | compares text (`4,0K`, `2,0M`) | converts everything to integer KiB |
| `/proc`, `/sys`, `/dev`, `/run` | `/proc/kcore` enters with 128T | excluded by default |
| Hardlink | `du` run per folder counts it twice | one single `du` invocation |
| Unreadable directory | stderr swallowed, list looks complete | warning with an unreadable count |
| USB/NFS mount | scan crosses it and hangs | `du -x` by default (`-X` to cross) |
| Total | cannot be checked | `--df-check` compares against `df` |

---

## Install

### One-liner

```sh
curl -fsSL https://raw.githubusercontent.com/glearflame/topdirs/main/topdirs \
  -o ~/.local/bin/topdirs
chmod +x ~/.local/bin/topdirs
```

### Clone (installer included)

```sh
git clone https://github.com/glearflame/topdirs.git
cd topdirs
./install.sh                 # ~/.local/bin as a regular user
sudo ./install.sh            # /usr/local/bin as root
```

`install.sh` warns if the destination is not in your shell `PATH` or not in
`sudo`'s `secure_path`.

### Making `sudo topdirs` work

`sudo` does not inherit your `PATH`. If `~/.local/bin` is not in
`secure_path`, install into `/usr/local/bin`:

```sh
sudo install -m755 topdirs /usr/local/bin/topdirs
```

Check with `sudo printenv PATH`. The Debian default includes
`/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin`.

### Requirements

- Linux with **Bash 4+**.
- **GNU coreutils** (`du`, `sort`, `realpath`, `numfmt`, `nice`).
- `util-linux` for `ionice` (optional, only with `-g`).
- `jq` (optional, only with `--json`).
- `awk` (optional, formatting fallback when `numfmt` is missing).

Not pure POSIX: it uses `sort -z`, `du -0` and `read -d`.

---

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
topdirs -g                       # nice 19 + ionice idle
```

### Options

| Option | Effect |
| --- | --- |
| `-n, --count N` | how many results (default: 20) |
| `-d, --depth N` | scan depth (default: 2) |
| `-a, --all` | include files — **see limitations: currently a no-op** |
| `-X, --cross-mounts` | cross into other filesystems (default: `du -x`) |
| `-e, --exclude PATTERN` | exclude a path (repeatable; default: `/proc /sys /dev /run`) |
| `-t, --threshold SIZE` | only entries above SIZE (`500M`, `2G`) |
| `--no-nested` | hide a folder inside another listed folder |
| `--df-check` | compare the scanned total against `df` used |
| `--apparent-size` | logical size instead of allocated blocks |
| `--json` | JSON output (a list of objects) |
| `--no-bar`, `--no-color`, `--ascii` | presentation |
| `-g, --gentle` | `nice 19` + `ionice idle` |
| `-q, --quiet` | table only |
| `-h, --help`, `-V, --version` | help and version |

**Note:** short options require a space (`-d 1`, not `-d1`). Long options
accept `=` (`--count=5`, `--depth=3`).

### Real examples

Threshold — only entries above 4 MiB:

```console
$ topdirs /tmp/opencode/demo -t 4M -n 6 --no-color --no-bar
> varrendo /tmp/opencode/demo (profundidade 2)

#       TAMANHO      %
 1    40.0MiB  79.9%   /tmp/opencode/demo/grande
 2     5.0MiB   9.9%   /tmp/opencode/demo/linkB

2 pasta(s) · total varrido 50.1MiB · 0s
Filesystem único (-x). Use -X para incluir outros mounts.
```

JSON — intact paths, ready for `jq`:

```console
$ topdirs /tmp/opencode/demo -n 2 --json | jq .
[
  {
    "path": "/tmp/opencode/demo/grande",
    "bytes": 41943040,
    "human": "40.0MiB",
    "percent": 79.99,
    "root": "/tmp/opencode/demo",
    "depth": 2
  },
  {
    "path": "/tmp/opencode/demo/linkB",
    "bytes": 5242880,
    "human": "5.0MiB",
    "percent": 9.99,
    "root": "/tmp/opencode/demo",
    "depth": 2
  }
]
```

---

## What the number means

By default: **allocated disk space** (blocks), not logical size. A 100 GiB VM
image that occupies 4 GiB shows as 4 GiB — what `df` sees. Use
`--apparent-size` for logical size.

Hardlinks are counted **once** (single `du` invocation), so the second folder
of a file with two links may show `0`. That is intentional.

The percentage is each folder's share of the **scanned total**, not of the
whole disk. Nested rows (parent and child) therefore add up to more than 100%.

### Proving the measurement with `--df-check`

`--df-check` compares the scanned total against the filesystem's `df` used. It
only makes sense when the target **is the mountpoint**:

```console
$ sudo topdirs /boot/efi --df-check -n 3 --no-color --no-bar
> varrendo /boot/efi (profundidade 2)

#       TAMANHO      %
 1     1.4GiB  69.6%   /boot/efi/966478645457402f8cc6e8782ae86b8d
 2   904.1MiB  45.7%   /boot/efi/966478645457402f8cc6e8782ae86b8d/limine_history
 3   235.7MiB  11.9%   /boot/efi/966478645457402f8cc6e8782ae86b8d/linux-cachyos

20 pasta(s) · total varrido 2.0GiB · 0s
Filesystem único (-x). Use -X para incluir outros mounts.

df do filesystem: 2.0GiB usado · varrido: 2.0GiB · diferença: 0.0B (0%)
```

As root on a real mountpoint the difference is 0%. Without root the difference
is exactly the size of the hole, and the script reports how many directories it
could not read.

---

## Limitations and known issues

Current behavior, documented instead of hidden:

- **`-a/--all` has no effect.** The flag is accepted and the footer says
  "Incluindo arquivos (-a)", but `du` is never called with `-a`, so only
  folders are ranked. Fix planned for 1.0.1.
- **`--df-check` on a subdirectory is misleading.** `df` reports the whole
  filesystem, not the folder. On `/boot` (same ext4 as `/` here) it prints
  `diferença: 93.5GiB (99%)` — expected, but the footer suggests other causes.
  Use it only on the mountpoint.
- **Combined short options do not work.** `-n10` and `-d1` fail with "unknown
  option"; use `-n 10` / `--count=10`.
- **Bind mounts.** A bind mount inherits the same `st_dev`, so `du -x` walks
  into it and may double count. Detecting that requires parsing mountinfo.
- **Deleted-but-open files** do not appear in `du` (no directory entry).
  `--df-check` exposes that gap when compared to `df`.
- **Layered storage** (btrfs, ZFS, Docker overlay) has no well-defined "folder
  size"; numbers are whatever is allocated there.
- **`--no-nested`** hides where the weight sits inside the ancestor. That is
  why it is opt-in (not the default).
- **Portuguese UI.** Headers, footers and warnings are not translatable yet;
  the data (`--json`) is neutral.

## Development

```sh
shellcheck topdirs install.sh    # passes (see .shellcheckrc)
bash -n topdirs                  # syntax
./topdirs -h                     # usage
```

`.shellcheckrc` documents two intentionally disabled warnings (SC2015 and
SC2329), both false positives explained in the file.

## License

MIT — copyright 2026 Glear flame. See [LICENSE](LICENSE).
