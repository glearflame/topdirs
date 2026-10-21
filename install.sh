#!/usr/bin/env bash
#
# install.sh — instala o topdirs.
#
# Uso:
#   ./install.sh                     # /usr/local/bin se for root, senão ~/.local/bin
#   ./install.sh /caminho/qualquer   # destino explícito
#
# O destino explícito é útil quando você quer `sudo topdirs` funcionando: o
# sudo não herda seu PATH, então ~/.local/bin fica invisível para ele.

set -euo pipefail

src="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/topdirs"

if [[ ! -f "$src" ]]; then
	printf 'install.sh: não encontrei %s\n' "$src" >&2
	exit 1
fi

dest="${1:-}"
if [[ -z "$dest" ]]; then
	if [[ "$(id -u)" -eq 0 ]]; then
		dest="/usr/local/bin"
	else
		dest="$HOME/.local/bin"
	fi
fi

install -d -- "$dest"
install -m 755 -- "$src" "$dest/topdirs"

printf 'topdirs instalado em %s/topdirs\n' "$dest"

# Aviso honesto: instalar não adianta nada se o shell não vê o diretório.
case ":$PATH:" in
*":$dest:"*) ;;
*) printf 'aviso: %s não está no PATH do seu shell\n' "$dest" >&2 ;;
esac

# E o sudo tem PATH próprio, separado do shell.
if [[ "$(id -u)" -ne 0 ]] && command -v sudo >/dev/null; then
	sudo_path="$(sudo printenv PATH 2>/dev/null || true)"
	if [[ -n "$sudo_path" ]]; then
		case ":$sudo_path:" in
		*":$dest:"*) ;;
		*)
			printf 'aviso: %s não está no secure_path do sudo — "sudo topdirs" vai falhar\n' "$dest" >&2
			printf '       instale com: sudo ./install.sh /usr/local/bin\n' >&2
			;;
		esac
	fi
fi
