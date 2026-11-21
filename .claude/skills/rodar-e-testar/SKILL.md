---
name: rodar-e-testar
description: Rodar, testar e fotografar o jogo Maré (Godot 4.7). Use para abrir o jogo, rodar o teste automático da missão, checar erros de script, tirar fotos automáticas de lugares e horários (antes e depois de mudar luz, modelos ou UI) e gravar vídeo. Use sempre que for conferir se uma mudança funcionou de verdade.
---

# Rodar e testar o Maré

O projeto Godot fica em `jogo/`. Quase tudo é montado **por código** em `jogo/scripts/main.gd` (terreno, rancho, vegetação, itens). A única cena é `scenes/main.tscn`.

## Onde está o Godot

```bash
G="${GODOT:-$(command -v godot || echo "$HOME/Applications/Godot.app/Contents/MacOS/Godot")}"
"$G" --version   # tem que ser 4.7.x
```

**Sempre** rode o Godot com `timeout`. No macOS, quando dá erro fatal, ele abre um alerta que o modo `--headless` não fecha, e o processo fica parado para sempre. Se sair com código 124, é falha.

## Checagem de erros (depois de qualquer mudança)

Rode na ordem e não pule nenhuma:

1. **Importar** (obrigatório depois de mudar `.glb`, textura ou `class_name`):
   `timeout 300 "$G" --headless --path jogo --import`
2. **Checar os scripts** abrindo o jogo por 60 quadros. Tem que imprimir `0`:
   `timeout 120 "$G" --headless --path jogo --quit-after 60 2>&1 | grep -cE "SCRIPT ERROR|Parse Error"`
   (Não use `--check-only --script`: ele não enxerga os autoloads `Mundo` e `Terreno` e acusa erro falso.)
3. **Teste da missão inteira.** Ele aperta as teclas de verdade e tem que terminar com `TESTE OK`:
   `timeout 300 "$G" --headless --path jogo -- --teste > teste.log 2>&1; grep -E "TESTE|SCRIPT ERROR" teste.log`

`SCRIPT ERROR` **não** derruba o jogo: a função para, mas o código de saída continua 0. Por isso, sempre procure no log com `grep`. Os avisos de vazamento de RID/ObjectDB ao fechar em modo headless são normais.

4. **Novo jogo pela pausa** (só se mexer em menus, salvar ou no `Mundo`): tem que imprimir `NOVO JOGO: ... -> OK`:
   `timeout 120 "$G" --headless --path jogo -- --teste-novo-jogo 2>&1 | grep "NOVO JOGO"`

Quando a mudança cria uma mecânica nova, inclua um passo para ela em `jogo/scripts/teste.gd`.

## Fotos automáticas (para comparar antes e depois)

As fotos precisam de janela de verdade (renderização Metal), então não use `--headless`:

```bash
timeout 180 "$G" --path jogo -- --fotos=rancho,mangue,toca --saida="$PASTA"
```

Lugares que existem em `_tirar_fotos()` no `main.gd`:
`inicio inicio_salvo rancho rancho_dentro mangue mangue2 toca puxando segurando lama poca cardume mira_tarrafa construir jirau inventario canoa pilotando naufragio ilha croa aratu_noite muricoca pincas palafita parabolica trapiche trapiche_rampa trapiche_cima mapa mapa_nomes areas tocas mare perigo noite por_do_sol sol lua chuva chuva_dentro chuva_porta panela galao facao facao_mao balde_mao`

Para mostrar um lugar novo, acrescente um `"nome":` no `match` de `_tirar_fotos()`, com `Mundo.hora` e `_posicionar(pos, yaw, pitch)`.

**Como trabalhar com as fotos:**
- Tire as fotos **antes** de mudar e guarde em `<scratchpad>/antes/`. Depois da mudança, tire de novo em `<scratchpad>/depois/`.
- Abra as imagens com Read e compare olhando. Não diga que melhorou sem ter visto as duas.
- Para luz, fotografe pelo menos `rancho rancho_dentro mangue sol por_do_sol noite lua chuva`.

## Desempenho

`timeout 120 "$G" --path jogo -- --medir` imprime `MEDIR quadro_ms=...`, o tempo de processador por quadro parado no mangue. A meta do projeto é 60 fps num computador comum.

## Vídeo (animações: facão, tarrafa, braço)

```bash
timeout 120 "$G" --path jogo --write-movie "$PASTA/q.png" --fixed-fps 30 --quit-after 150 -- --fotos=facao_mao
ffmpeg -y -framerate 30 -pattern_type glob -i "$PASTA/q*.png" -pix_fmt yuv420p "$PASTA/video.mp4"
```

O `ffmpeg` não vem instalado; sem ele, analise os quadros `.png` direto (abra 1 a cada 5 com Read). `--write-movie` não funciona com `--headless`. Use um script de teste para apertar as teclas durante a gravação.

## Abrir para a pessoa jogar

```bash
"$G" --path jogo   # em segundo plano; o log aparece no stdout
```

## Armadilhas do Godot que não dão erro

Adaptado do guia GDScript do [Godogen](https://github.com/htdt/godogen), licença MIT.

- Malha feita por código sem `SurfaceTool.generate_normals()` **não recebe sombra**. Usar `CULL_DISABLED` para "garantir" também apaga a sombra. O certo é corrigir a ordem dos vértices.
- `create_trimesh_collision()` em modelo importado pesado derruba o FPS. Prefira caixa, cápsula ou esfera do tamanho do AABB. Raio contra trimesh também pode falhar; a altura do chão vem de `Terreno.altura(x, z)`.
- `:=` não aceita valor sem tipo (`load(...).instantiate()`, `abs`, `lerp`, `max`). Declare o tipo ou use `absf`, `lerpf`, `maxf`.
- Amortecimento independente do FPS: `v *= exp(-taxa * delta)`, nunca `v *= 0.9` por quadro.
- Um `.gdignore` dentro de uma pasta faz o Godot ignorar a pasta inteira sem avisar.
