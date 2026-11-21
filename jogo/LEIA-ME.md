# MARÉ — sobrevivência no mangue (MVP)

Nome provisório. O caranguejo é o símbolo do jogo. As missões usam termos do mangue beat: "Caranguejo com Cérebro" (do manifesto de 1992) e "Parabólica na Lama" (a antena fincada no mangue).

Jogo em primeira pessoa feito no **Godot 4.7**, com os objetos 3D modelados no **Blender** por script.

## Jogar

Abra o Godot e importe esta pasta (`jogo/`), ou rode no terminal:

```bash
godot --path jogo
```

| Tecla | O que faz |
|---|---|
| W A S D | andar |
| SHIFT | correr (gasta força) |
| ESPAÇO | pular / puxar a perna quando atolar |
| E | usar / pegar / cortar lenha com o facão / guardar o caranguejo no balde |
| R | soltar o caranguejo |
| G | largar o balde no chão |
| F | lanterna |
| M | mapa (mostra onde a maré está agora) |
| CTRL ou OPTION | agachar (segure): passa embaixo do trapiche |
| ESPAÇO perto de borda alta | agarra e sobe (trapiche, assoalho), inclusive saindo da água |
| I (ou TAB) | inventário: mochila (6 espaços) e balde (10); clique no peixe para passar entre os dois, clique na farofa para comer |
| T | tarrafa: segure para mirar, solte para jogar em cima do cardume |
| B | construir jirau-fogão (aparece verde onde dá, vermelho onde não dá; E constrói) |
| ESC | pausa |
| **Na toca** | **segure E** para enfiar o braço · quando achar o caranguejo, **ESPAÇO** para agarrar (centro do verde = pegada **forte**, borda = fraca, vermelho = pinçada) · **segure E** para puxar e **solte** quando aparecer "SOLTE!" · com pegada forte ele nunca escapa · **S** tira o braço |

## O que já tem (MVP da seção 8 do MECANICAS.md)

- Mapa de 260 × 260 m: rancho na terra firme, mangue de lama, igarapé, baía e croa.
- **Maré** que sobe e desce a cada 12,4 h (1 h de jogo = 1,5 min reais), cobre as tocas mais baixas primeiro e, na cheia, alaga o mangue até o peito. Embaixo d'água a lama prende a perna. Para se salvar, volte para o rancho ou suba num **teso** (morrinho de terra firme, marcado de verde na bússola quando há perigo).
- Mangue com trechos fechados de árvore. Terra firme só no alto; a lama fica nas partes baixas.
- **Lama mole:** manchas irregulares quase pretas onde a perna atola. A lama firme, mais clara, é o caminho fácil. Na lama mole tem bem mais toca.
- **Peixe:** cardumes nadando na superfície (fogem quando você chega perto), tainhas pulando, e **poças da vazante** com peixe preso que dá para pegar com a mão (E). Peixe vai para o balde e cozinha junto com o caranguejo.
- **Céu:** sol com brilho, lua com fases (29,5 dias), estrelas e nuvens que andam. O jogo começa em 1º de maio.
- **Clima do Maranhão:** chuva de janeiro a junho (pico em março e abril, mais à tarde), seca de agosto a novembro; temporal com relâmpago; o chão fica encharcado. Maré maior na lua cheia e na nova ("maré de lua").
- **Mapa (M) e minimapa** com rancho, fogão, tesos, objetivo e a água da maré do momento.
- **Dia e noite**, com neblina de manhã e lanterna.
- **Corpo:** fome, força, lama que atola, água funda que obriga a nadar e peso da carga.
- **Tocas destacadas:** anel dourado na boca e marcador "Toca" com a distância quando você chega perto.
- **Toca de caranguejo:** a toca pode estar vazia ou ocupada (bolinhas de lama fresca são o sinal). O caranguejo pode estar de pinça aberta e dar pinçada, e pode escapar mais para o fundo se você puxar forte demais. Fêmea e miúdo devem ser soltos.
- **Caranguejo com cérebro:** os que andam na lama fogem para a toca quando você chega perto, e os vizinhos fogem junto. Encurralado longe da toca, ele levanta as pinças e ameaça (pegar nessa hora pode dar beliscão). Na toca, se você errar muito ou segurar fraco, ele pode escapar por uma toca vizinha e sair correndo.
- **Balde** com capacidade de 10. Se você largar o balde e a maré chegar, os caranguejos fogem.
- **Facão** na mão: corta lenha dos troncos caídos. A lenha vai para a **mochila** (até 4).
- **Fogão de 3 pedras:** lenha → isqueiro → panela (os caranguejos aparecem lá dentro e ficam vermelhos quando cozinham) → comer com farinha.
- **Jirau-fogão** (B): fogão suspenso de pau, talo e lama, montado em qualquer lugar do mangue com 2 feixes de lenha, por etapas (pés → talos → lama). Funciona igual ao fogão do rancho, com a panelinha da mochila. Fica a 85 cm do chão; se a maré passar disso, apaga o fogo.
- **Mochila e balde:** a mochila tem 6 espaços (3 peixes, 2 feixes de lenha, 1 cuia de farinha ou 2 farofas por espaço). Caranguejo só no balde. Você começa com farofa para comer em qualquer lugar.
- **Saúde e perigos:** barra de saúde separada da força. Arraia enterrada na água rasa ferroa quem corre (ande sem correr); muriçoca no amanhecer, entardecer e noite (lama no rosto pelo inventário, ou fumaça do fogo); bagre das poças tem esporão; pinçada tira saúde. Sem força na água funda você engole água e perde saúde aos poucos; parado, você boia e descansa (se não estiver pesado).
- **Tarrafa** (no rancho): pega vários peixes do cardume de uma vez; depois o cardume fica arisco.
- **Aratu:** caranguejo pequeno que sobe nas raízes na maré cheia. Mãozada; à noite com lanterna é mais fácil.
- **Rede:** dormir até a próxima maré baixa, mostrando o relógio passar.
- Missão do primeiro dia, bússola com marcadores e avisos na tela.
- **Missão "Parabólica na Lama"** (começa depois do primeiro dia): ache a canoa velha na margem do igarapé, junte as peças espalhadas (hélice na croa, remo no mangue, cuia perto de um teso, galão preso nas raízes, breu e motor no barco abandonado da baía, que só aparece na maré baixa). O motor vem cheio de lama e sal: lave com **água doce** da bacia do rancho, que só enche quando chove, na bancada. Monte tudo na canoa e pilote até a **ilha** do outro lado da baía. Ao chegar perto da canoa, a lista de peças aparece sozinha; o mapa e a bússola mostram um **círculo azul de busca** para cada peça (perto, sem o ponto exato), e dentro do círculo é procurar o brilho azul.
- **Canoa:** W/S acelera e freia, A/D vira, E desce. Gasta gasolina; sem gasolina vai no remo. Encalha no raso e bate nas raízes — na maré cheia dá para cortar caminho por dentro do mangue.

## Um mangue só, com o Brasil inteiro dentro

O mapa é um mangue do **Maranhão** (maré gigante de lua, igarapés, croas, bumba-meu-boi), com homenagens a **Pernambuco** e ao mangue beat:

- **Parabólica na Lama:** torre enferrujada de uns 7 m, com plataforma, prato grande, pés de aço e pés que viraram raiz de mangue, cravada num monte de lama com tocas em volta. Ajuste o prato (E) para pegar o sinal: o mapa passa a mostrar os nomes dos lugares e a **tábua de marés** (próximas cheias e baixas).
- **Palafita do Capibaribe:** casa colorida de tábua sobre estacas na beira do igarapé. É um abrigo alto: a maré não chega no assoalho, e tem rede e lenha.
- **Nomes misturando os dois lugares** (todos inventados): Igarapé do Uçá, Croa Grande, Mangue do Siri, Baía do Boi, Ilha do Maracatu, Barco Encalhado, Teso do Bumba, Teso do Frevo, Teso do Reggae.

**Ideia para o futuro: vários cenários.** Cada mangue com sua regra principal:
- *Maranhão* (este): maré gigante que alaga tudo, igarapés, croas, ilhas.
- *Pernambuco*: mangue colado na cidade, palafitas, pontes e rios, maré menor mas com a cidade em volta.
- Outros possíveis: Pará (rios enormes, açaí), Bahia (Baía de Todos-os-Santos, mariscagem).

## Jogo salvo

O jogo salva sozinho a cada 2 minutos, ao dormir na rede, ao concluir uma etapa de missão e ao fechar a janela. Ao abrir, a tela inicial mostra **Continuar** (com o dia e a hora do save) ou **Novo jogo**. O arquivo fica em `~/Library/Application Support/mare_jogo/save.json`. Os testes e as fotos automáticas usam outro arquivo e não mexem no seu save.

## Pastas

- `assets/` — objetos .glb gerados pelo Blender (não editar à mão; gerar de novo pelo script).
- `../blender/externos/` — modelos CC0 do Poly Haven (facão, galão, panela, lata, tronco caído, pneu, chapéu, botas, balde de madeira, cofo, trapiche, boia, caixa plástica, samambaia). `../blender/importar_externos.py` ajusta e exporta para `assets/` com o mesmo nome dos modelos antigos; rode depois do `gerar_assets.py`.
- `assets/texturas/` — texturas reais do Poly Haven (CC0), aplicadas no chão pelo shader e nos objetos por `scripts/texturas.gd` (pelo nome do material do Blender).
- `scripts/` — lógica do jogo (`main.gd` monta o mundo, `jogador.gd`, `toca.gd`, `fogao.gd`, `hud.gd`, `missoes.gd`...).
- `shaders/` — chão (lama/areia/terra), água barrenta e vinheta.
- `../blender/gerar_assets.py` — modela e exporta todos os objetos.

Para gerar os objetos de novo depois de mudar o script:

```bash
/Applications/Blender.app/Contents/MacOS/Blender -b -P blender/gerar_assets.py
```

## Testes

```bash
godot --headless --path jogo -- --teste
```

Esse comando joga a missão inteira sozinho, apertando as teclas, e termina com `TESTE OK`.

```bash
godot --path jogo -- --fotos=rancho,mangue,toca,mare,noite --saida=/tmp
```

Esse comando tira fotos automáticas de cada situação.

## Ajustes fáceis

- Duração do dia: `SEGUNDOS_REAIS_POR_HORA` em `scripts/mundo.gd`.
- Altura e velocidade da maré: `MARE_AMPLITUDE` e `PERIODO_MARE` em `scripts/mundo.gd`.
- Meta de caranguejos: `META` em `scripts/missoes.gd`.
