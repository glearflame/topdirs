# topdirs

[![Licença: MIT](https://img.shields.io/badge/licen%C3%A7a-MIT-blue.svg)](LICENSE)
[![Shell: Bash 4+](https://img.shields.io/badge/shell-bash%204%2B-4EAA25?logo=gnubash&logoColor=white)](#instala%C3%A7%C3%A3o)
[![Plataforma: Linux](https://img.shields.io/badge/plataforma-Linux-lightgrey?logo=linux&logoColor=black)](#instala%C3%A7%C3%A3o)

As maiores pastas do seu sistema, com o caminho completo — em um comando, sem
mentir para você.

**Português (BR)** · [English](README.md)

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

*(Saída real, executada em Kali/Debian com ext4. Os percentuais são a fatia de
cada pasta no total varrido; por isso pai e filho podem somar mais de 100%.)*

Um script Bash, um arquivo, sem dependências além do `coreutils`. `jq` só é
necessário para `--json`.

---

## O problema: `du -h | sort -h | head`

O pipeline que todo mundo escreve não responde "quais são as maiores pastas".
Ele responde "quais são as **menores**", porque `sort -h` ordena do menor para
o maior e `head` pega o começo. Além disso, ele quebra em nomes com newline.

Teste real num diretório de demonstração com 4 KiB, 2 MiB, 3 MiB, 5 MiB
(hardlink) e 40 MiB:

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

Três coisas erradas nessa saída:

1. **As menores pastas aparecem primeiro.** A pasta de 40 MiB está na sexta
   linha; um `head -5` nunca a mostraria.
2. **O nome com newline virou duas linhas** (`.../nome` e `quebrado`), e a
   segunda não tem tamanho — qualquer processamento a jusante recebe lixo.
3. **`du` humano tem precisão de uma casa e unidades mistas.** Comparar texto
   como `4,0K` e `2,0M` funciona por sorte no GNU `sort -h`; comparar os
   inteiros em KiB, como o `topdirs` faz, funciona sempre.

E há os casos que não aparecem nesse exemplo:

```console
$ for d in linkA linkB; do du -sh "$d"; done
5,0M	linkA
5,0M	linkB          # mesmo inode contado duas vezes

$ du --apparent-size -h --max-depth=0 /proc/kcore
128T	/proc/kcore     # tamanho "lógico" absurdo, não espaço ocupado
```

O mesmo diretório, medido pelo `topdirs`:

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

O nome com newline é **escapado na exibição** (`\n`) mas continua íntegro no
JSON. O hardlink aparece uma vez só: `linkA` mostra `0.0B` porque o inode já
foi contabilizado em `linkB` — é o espaço real que o `df` enxerga.

### O que o `topdirs` faz de diferente

| Armadilha | O que o pipeline ingênuo faz | O que o `topdirs` faz |
| --- | --- | --- |
| `sort -h \| head` | mostra as **menores** pastas | ordena numérico em KiB e pega as maiores |
| Nome com newline/tab | quebra a linha e corrompe o ranking | pipeline NUL (`du -0`, `sort -z`) |
| Unidades humanas | compara texto (`4,0K`, `2,0M`) | converte tudo para KiB inteiro antes de ordenar |
| `/proc`, `/sys`, `/dev`, `/run` | `/proc/kcore` entra com 128T | excluídos por padrão |
| Hardlink | `du` separado por pasta conta duas vezes | uma única invocação de `du`, conta uma vez |
| Diretório sem permissão | erro no `stderr`, lista parece completa | aviso com a contagem de diretórios ilegíveis |
| Mount USB/NFS | varredura atravessa e trava | `du -x` por padrão (use `-X` para atravessar) |
| Total | não dá para conferir | `--df-check` compara com o `df` |

---

## Instalação

### Uma linha (script direto)

```sh
curl -fsSL https://raw.githubusercontent.com/glearflame/topdirs/main/topdirs \
  -o ~/.local/bin/topdirs
chmod +x ~/.local/bin/topdirs
```

### Clonando (instalador incluído)

```sh
git clone https://github.com/glearflame/topdirs.git
cd topdirs
./install.sh                 # ~/.local/bin se usuário comum
sudo ./install.sh            # /usr/local/bin se root
```

O `install.sh` avisa se o destino não está no `PATH` do seu shell e se ele não
está no `secure_path` do `sudo`.

### Para `sudo topdirs` funcionar

O `sudo` não herda o seu `PATH` (usa `secure_path`). Se `~/.local/bin` não
estiver lá, instale em `/usr/local/bin`:

```sh
sudo install -m755 topdirs /usr/local/bin/topdirs
```

Confira com `sudo printenv PATH`. O padrão Debian inclui
`/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin`.

### Requisitos

- Linux com **Bash 4+**.
- **GNU coreutils** (`du`, `sort`, `realpath`, `numfmt`, `nice`).
- `util-linux` para `ionice` (opcional, só com `-g`).
- `jq` (opcional, só com `--json`).
- `awk` (opcional, fallback de formatação se `numfmt` não existir).

Não é POSIX puro: usa `sort -z`, `du -0` e `read -d`.

---

## Uso

```sh
topdirs                          # top 20 de /, profundidade 2
sudo topdirs                     # varredura completa (recomendado)
topdirs /home -n 10              # top 10 dentro de /home
topdirs -d 1                     # totais por diretório de primeiro nível
topdirs -d 3 --no-nested         # sem pai e filho no mesmo ranking
topdirs -X -d 1                  # inclui /mnt, /media, discos externos
topdirs -t 1G -d 4 /var          # só o que passa de 1 GiB em /var
topdirs --json | jq -r '.[].path'
topdirs -g                       # nice 19 + ionice idle: não estressa o disco
```

### Opções

| Opção | Efeito |
| --- | --- |
| `-n, --count N` | quantos resultados (padrão: 20) |
| `-d, --depth N` | profundidade da varredura (padrão: 2) |
| `-a, --all` | incluir arquivos — **ver limitações: hoje não tem efeito** |
| `-X, --cross-mounts` | atravessar outros filesystems (padrão: `du -x`) |
| `-e, --exclude PADRÃO` | excluir caminho (repetível; padrão: `/proc /sys /dev /run`) |
| `-t, --threshold TAM` | só o que passar de TAM (`500M`, `2G`) |
| `--no-nested` | esconder pasta que já está dentro de outra listada |
| `--df-check` | comparar o total varrido com o `usado` do `df` |
| `--apparent-size` | tamanho lógico em vez de espaço ocupado |
| `--json` | saída JSON (uma lista de objetos) |
| `--no-bar`, `--no-color`, `--ascii` | apresentação |
| `-g, --gentle` | `nice 19` + `ionice idle` |
| `-q, --quiet` | só a tabela |
| `-h, --help`, `-V, --version` | ajuda e versão |

**Atenção:** opções curtas exigem espaço (`-d 1`, não `-d1`). As formas longas
com `=` funcionam (`--count=5`, `--depth=3`).

### Exemplos reais

Threshold — só o que passa de 4 MiB:

```console
$ topdirs /tmp/opencode/demo -t 4M -n 6 --no-color --no-bar
> varrendo /tmp/opencode/demo (profundidade 2)

#       TAMANHO      %
 1    40.0MiB  79.9%   /tmp/opencode/demo/grande
 2     5.0MiB   9.9%   /tmp/opencode/demo/linkB

2 pasta(s) · total varrido 50.1MiB · 0s
Filesystem único (-x). Use -X para incluir outros mounts.
```

JSON — caminhos íntegros, mesmo com newline, prontos para `jq`:

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

## Semântica: o que o número significa

Por padrão, **espaço ocupado em disco** (blocos alocados), não tamanho lógico.
Uma imagem de VM de 100 GiB que ocupa 4 GiB aparece como 4 GiB — é o que o
`df` enxerga. Use `--apparent-size` para o tamanho lógico.

Hardlinks são contados **uma única vez** (uma passada só de `du`), então a
segunda pasta de um arquivo com dois links pode aparecer como `0`. É
proposital.

O percentual é a fatia daquela pasta no **total varrido**, não no disco todo.
Por isso linhas aninhadas (pai e filho) somam mais de 100%.

### Conferindo a medição com `--df-check`

`--df-check` compara o total varrido com o `usado` do filesystem. Só faz
sentido quando o alvo **é o ponto de montagem**:

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

Com root num mountpoint real, a diferença fica em 0%. Sem root a diferença é
o tamanho exato do buraco na lista, e o script informa quantos diretórios não
pôde ler.

---

## Limitações e problemas conhecidos

Comportamento atual, documentado em vez de escondido:

- **`-a/--all` não tem efeito.** A flag é aceita e o rodapé diz "Incluindo
  arquivos (-a)", mas o `du` não recebe `-a`, então só pastas entram no
  ranking. Correção planejada para a 1.0.1.
- **`--df-check` em subdiretório engana.** O `df` reporta o filesystem inteiro,
  não a pasta. Em `/boot` (que neste sistema está no mesmo ext4 de `/`), a
  saída mostra `diferença: 93.5GiB (99%)` — esperado, mas o rodapé sugere
  outras causas. Use apenas no ponto de montagem.
- **Opções curtas coladas não funcionam.** `-n10` e `-d1` dão "opção
  desconhecida"; use `-n 10`, `--count=10`.
- **Bind mounts.** Um bind mount herda o mesmo `st_dev`, então `du -x`
  atravessa e pode contar duas vezes. Detectar exigiria ler o `mountinfo`.
- **Arquivo apagado mas ainda aberto** não aparece no `du` (sem directory
  entry). `--df-check` revela esse buraco na comparação com o `df`.
- **Armazenamento em camadas** (btrfs, ZFS, Docker overlay) não tem noção de
  "tamanho da pasta" bem definida; os números são do que está alocado ali.
- **`--no-nested`** esconde onde o peso está dentro do ancestral. É opt-in
  justamente por isso.
- **Saída em português.** A interface (cabeçalho, rodapé, avisos) ainda não é
  traduzível; os dados (`--json`) são neutros.

## Desenvolvimento

```sh
shellcheck topdirs install.sh    # passa (veja .shellcheckrc)
bash -n topdirs                  # sintaxe
./topdirs -h                     # uso
```

O `.shellcheckrc` documenta dois avisos desativados de propósito (SC2015 e
SC2329), ambos falsos positivos explicados no próprio arquivo.

## Licença

MIT — copyright 2026 Glear flame. Veja [LICENSE](LICENSE).
