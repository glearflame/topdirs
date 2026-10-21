# topdirs

As maiores pastas do seu sistema, com o caminho completo — em uma linha de
comando, sem mentir.

```
$ sudo topdirs
> varrendo / (profundidade 2)

#       TAMANHO      %
 1    43.6GiB  46.9%  ██████████············ /usr
 2    31.7GiB  34.1%  ███████··············· /home
 3    31.7GiB  34.1%  ███████··············· /home/spingat
 4    18.8GiB  20.1%  ████·················· /usr/lib
 5    18.0GiB  19.3%  ████·················· /usr/share
 6    14.5GiB  15.5%  ███··················· /var
 7    13.3GiB  14.2%  ███··················· /var/lib
 8     5.1GiB   5.4%  █····················· /usr/bin
 9   936.0MiB   0.9%  █····················· /var/log

311 pasta(s) · total varrido 92.9GiB · 11s
Filesystem único (-x). Use -X para incluir outros mounts.
```

## Instalação

Um arquivo, sem dependências além de `coreutils`. `jq` só é necessário para
`--json`, e `numfmt` tem fallback em `awk`.

```sh
curl -fsSL https://raw.githubusercontent.com/glearflame/topdirs/main/topdirs \
  -o ~/.local/bin/topdirs
chmod +x ~/.local/bin/topdirs
```

Ou, clonando o repo:

```sh
git clone https://github.com/glearflame/topdirs.git
install -m755 topdirs/topdirs ~/.local/bin/topdirs
```

Funciona em qualquer distro Linux com Bash 4+ e GNU coreutils (testado em
Debian/Kali). Não é POSIX puro: usa `sort -z`, `du -0` e `read -d`.

### Para usar com `sudo`

`~/.local/bin` não está no `PATH` do `sudo` (ele usa `secure_path`). Se
`sudo topdirs` responder `comando não encontrado`, instale em
`/usr/local/bin`:

```sh
sudo install -m755 topdirs /usr/local/bin/topdirs
```

Se `/usr/local/bin` também não estiver no `secure_path` do seu `sudoers`,
confira com `sudo printenv PATH`. O padrão Debian inclui
`/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin`; se o seu foi
customizado para menos, ajuste o `Defaults secure_path` (ou use
`sudo env "PATH=$PATH" topdirs`).

## Uso

```sh
topdirs                          # top 20 de /, profundidade 2
sudo topdirs                     # versão completa (recomendado)
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
| `-a, --all` | incluir arquivos, não só pastas |
| `-X, --cross-mounts` | atravessar outros filesystems (padrão: `du -x`) |
| `-e, --exclude PADRÃO` | excluir caminho (repetível; padrão: `/proc /sys /dev /run`) |
| `-t, --threshold TAM` | só o que passar de TAM (`500M`, `2G`) |
| `--no-nested` | esconder pasta que já está dentro de outra listada |
| `--df-check` | comparar o total varrido com o `usado` do `df` |
| `--apparent-size` | tamanho lógico em vez de espaço ocupado |
| `--json` | saída JSON |
| `--no-bar`, `--no-color`, `--ascii` | apresentação |
| `-g, --gentle` | `nice 19` + `ionice idle` |
| `-q, --quiet` | só a tabela |
| `-h, --help`, `-V, --version` | ajuda e versão |

## Por que não `du -h | sort -h | head -20`

Porque esse pipeline erra em casos que aparecem no mundo real:

| Problema | O que acontece | O que o `topdirs` faz |
| --- | --- | --- |
| Nome com newline ou tab | linha quebra, caminho vira lixo no ranking | pipeline NUL (`du -0`, `sort -z`) |
| Locale `pt_BR` | `sort -h` compara `1,2G` como texto | `LC_ALL=C` + ordenação numérica em KiB |
| `/proc`, `/sys` | `/proc/kcore` aparece com tamanho absurdo | excluídos por padrão |
| Hardlink | dois scripts somam o mesmo arquivo duas vezes | uma invocação só de `du` (conta uma vez) |
| Diretório sem permissão | erro no stderr, lista parece completa | aviso explícito com a contagem |
| Mount USB/NFS | varredura trava por minutos | `du -x` por padrão |

## Semântica: o que o número significa

Por padrão, **espaço ocupado em disco** (blocos alocados), não tamanho lógico.
Uma imagem de VM de 100 GiB que ocupa 4 GiB aparece como 4 GiB — é o que o
`df` enxerga. Use `--apparent-size` para o tamanho lógico.

Hardlinks são contados **uma única vez**, então a segunda pasta de um arquivo
com dois links pode aparecer como `0`. Isso é proposital.

### Conferindo a medição

`--df-check` compara o total varrido com o `usado` do `df`:

```
$ sudo topdirs -n 3 --no-bar --df-check /
df do filesystem: 92.9GiB usado · varrido: 92.9GiB · diferença: 4.2MiB (0%)
```

Com root, a diferença fica abaixo de 0.1% — é a prova de que a medição está
correta. Sem root:

```
df do filesystem: 92.9GiB usado · varrido: 92.5GiB · diferença: 455.3MiB (0%)
AVISO: 65 diretório(s) sem permissão de leitura — total subestimado.
```

A diferença é o tamanho exato do buraco na lista.

## Limitações conhecidas

- **Bind mounts.** Um bind mount herda o mesmo `st_dev`, então `du -x`
  atravessa e pode contar duas vezes. Detectar exigiria ler o mountinfo.
- **Arquivo apagado mas ainda aberto** não aparece no `du` (sem directory
  entry). `--df-check` revela esse buraco na comparação com o `df`.
- **Armazenamento em camadas** (btrfs, ZFS, Docker overlay) não tem noção de
  "tamanho da pasta" bem definida; os números são do que está alocado por ali.
- **`--no-nested`** esconde onde o peso está dentro do ancestral. É opt-in
  justamente por isso.

## Licença

MIT. Veja [LICENSE](LICENSE).
