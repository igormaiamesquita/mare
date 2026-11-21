# Como ajudar

Toda ajuda é bem-vinda: jogar e contar o que achou, código, modelos 3D, texturas, som, ideias e pesquisa sobre o mangue e quem vive dele.

## Jogou e quer contar?

Abra uma [issue](https://github.com/igormaiamesquita/mare/issues/new/choose): tem formulário para **problema** (bug) e para **ideia**. Uma foto da tela ajuda muito (no Mac: Cmd+Shift+4; no Windows: Win+Shift+S).

## Quer mexer no jogo?

1. Abra uma *issue* contando o que quer fazer (ou pegue uma aberta, especialmente as marcadas **bom primeiro passo**).
2. Faça um *fork*, trabalhe num *branch* e abra um *pull request*.
3. Antes de mandar, rode as checagens abaixo. Elas também rodam sozinhas no GitHub em todo *pull request*.

### Checagens

Com o [Godot 4.7](https://godotengine.org/download) instalado (troque `godot` pelo caminho do seu, se precisar):

```bash
godot --headless --path jogo --import                 # depois de mudar modelos, texturas ou class_name
godot --headless --path jogo --quit-after 60          # não pode aparecer "SCRIPT ERROR" nem "Parse Error"
godot --headless --path jogo -- --teste               # joga as missões sozinho; tem que terminar com TESTE OK
godot --headless --path jogo -- --teste-novo-jogo     # "Novo jogo" da pausa; tem que dar OK
```

Mexeu em algo que aparece na tela? Tire fotos antes e depois e mande no *pull request*:

```bash
godot --path jogo -- --fotos=rancho,mangue,toca,noite --saida=/uma/pasta          # com a interface
godot --path jogo -- --fotos=rancho,por_do_sol --sem-hud --saida=/uma/pasta       # sem a interface
```

A lista de lugares fica em `_tirar_fotos()` no `jogo/scripts/main.gd` (dá para criar novos).

### Modelos 3D e ícones

- Os modelos feitos para o jogo são **código**: `blender/gerar_assets.py`. Para exportar só alguns:
  `blender -b -P blender/gerar_assets.py -- rancho.glb rede.glb`
- Modelos de terceiros ficam em `blender/externos/` e são ajustados por `blender/importar_externos.py` (`-- rubber_boots` para só um).
- Convenção: metros, Z para cima, frente para +Y, origem no chão.
- Os ícones da interface são fotos dos modelos: `godot --path jogo -- --icones` (ou `--icones --so=facao,remo`).

### Usa o Claude Code?

O projeto tem *skills* em `.claude/skills/` (rodar e testar, arte 3D) com o passo a passo acima, para o assistente seguir o mesmo caminho.

## Regras do projeto

- **Obra original.** O jogo se inspira no modo de vida de quem vive do mangue, mas não usa nome, imagem, voz ou bordões de pessoas reais.
- **Só material livre.** Arte e som de terceiros só com licença **CC0** ou **CC BY** (nada de "não comercial" ou "sem derivados"), com o crédito no `CREDITOS.md` da pasta e no `LICENCA-ARTE.md`.
- **Português** nos textos do jogo e nos nomes do código.
- **Desempenho:** precisa rodar a 60 quadros por segundo num computador comum. Objetos com muitos milhares de faces precisam ser simplificados (veja `blender/importar_externos.py`).
- **Mudou uma mecânica?** Acrescente um passo no teste (`jogo/scripts/teste.gd`).

## Bons primeiros passos

- **Som** (o jogo ainda não tem nenhum): maré, chuva, vento no mangue, passarinhos, muriçoca, caranguejo, fogo. Dá para começar com sons CC0 do [freesound](https://freesound.org).
- Árvores de mangue mais realistas: mangue-vermelho com raízes-escora, siriúba com pneumatóforos.
- Mão e braço em primeira pessoa, com animação de pegar, cortar e jogar a tarrafa.
- Caranguejo-uçá com as cores de verdade (azulado, patas peludas), siri, ostra.
- Pesca com linha e curral, turu.
- Coisas para fazer na ilha; outros cenários de mangue (Pernambuco, Pará, Bahia).
- Tradução (inglês e espanhol), para mais gente jogar.
