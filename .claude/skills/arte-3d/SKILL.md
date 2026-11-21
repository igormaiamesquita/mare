---
name: arte-3d
description: Fazer, trocar ou consertar modelos 3D e texturas do Maré (Blender 5.3 + Godot). Use para modelar no Blender (por script ou pelo Blender MCP), procurar modelos livres (Poly Haven, Sketchfab, ambientCG, Quaternius), importar e ajustar modelos de terceiros, conferir licença e créditos, e levar o resultado para jogo/assets.
---

# Arte 3D do Maré

## O caminho de um modelo

```
blender/gerar_assets.py       → modelos feitos por nós (código) ───┐
blender/externos/<id>/*.gltf  → modelos de terceiros (CC0/CC BY)   ├→ jogo/assets/<nome>.glb → main.gd / cultura.gd
blender/importar_externos.py  → ajusta os de terceiros ────────────┘
```

- Blender: `B="${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}"`
- Gerar tudo: `"$B" -b -P blender/gerar_assets.py` e, em seguida, `"$B" -b -P blender/importar_externos.py`. O segundo **sobrescreve** alguns `.glb` do primeiro com o mesmo nome.
- O jogo carrega pelo nome (`res://assets/<nome>.glb`). Trocar um modelo mantendo o nome não exige mudar código.
- Depois de exportar, rode a importação e tire as fotos (skill `rodar-e-testar`).

## Ícones da interface

Os ícones (`jogo/assets/icones/*.png`) são **fotos dos próprios modelos**, feitas por `jogo/scripts/icones.gd`. Mudou um modelo ou criou um item? Acrescente na lista `ITENS` (modelo, rotação, giro na tela) e gere de novo:
`timeout 400 "$G" --path jogo -- --icones` (ou `--icones --so=facao,remo` para só alguns), depois `--headless --import`. Precisa de janela (não use `--headless`). Para conferir todos de uma vez, monte uma folha de contato com Pillow (`uv run --with pillow`).

## Convenções (o código depende delas)

- Metros, **Z para cima**, a **frente aponta para +Y**. O exportador glTF converte para o padrão do Godot.
- A origem fica **no chão, no centro** (onde o objeto encosta). Ferramentas de mão têm a origem no cabo e a lâmina para +Y.
- Materiais com nomes em português (`madeira_rancho`, `lamina`). A função `material()` reaproveita pelo nome.
- **Desempenho:** objeto pequeno até ~6 mil faces; árvore até ~10–15 mil, com LOD; cenário grande até ~20 mil. Use `alvo de faces` em `importar_externos.py` para simplificar.
- Texturas em **1K**, no máximo 2K para coisas que aparecem perto (mão, facão, balde).

## Blender MCP (Blender aberto, controlado pelo Claude)

Com o Blender aberto e o add-on **MCP for Blender** ativo (aba no painel N → Start MCP Server), as ferramentas `mcp__blender__*` ficam disponíveis:
- ver a cena e tirar print da viewport → use para **olhar** o modelo antes de exportar
- rodar Python no Blender → para modelar interativamente
- buscar e baixar do **Poly Haven** e do **Sketchfab** direto na cena (o Sketchfab precisa de chave de API configurada no add-on)

**Regra:** o que for modelado pelo MCP precisa virar **código** em `gerar_assets.py` ou um modelo em `blender/externos/` com entrada em `importar_externos.py`. Assim qualquer pessoa consegue gerar de novo. Não deixe modelo existindo só dentro de um `.blend`.

## Procurar modelos livres

| Fonte | Licença | Bom para |
|---|---|---|
| [Poly Haven](https://polyhaven.com) | CC0 | objetos realistas, plantas, **texturas** (já é a base do jogo) |
| [ambientCG](https://ambientcg.com) | CC0 | texturas: lama, areia, casca, palha, madeira |
| [Quaternius](https://quaternius.com) | CC0 | natureza, palmeiras, personagens **com rig e animação** |
| [Kenney](https://kenney.nl) | CC0 | ícones, sons de interface, protótipos |
| [Sketchfab](https://sketchfab.com/search?features=downloadable&licenses=7c23a1ba438d4306920229c12afcb5f9&type=models) | CC BY (filtrar) | coisas específicas: coqueiro, canoa, mangue |
| [freesound](https://freesound.org) | CC0 / CC BY | maré, chuva, mangue, caranguejo |

**Licença, sem exceção:**
- Só **CC0** ou **CC BY**. Recuse NC (não comercial), ND (sem derivados), "Standard"/"Editorial" e "uso pessoal".
- Confira a licença **na página do modelo**, não na lista de busca.
- Registre em `blender/externos/CREDITOS.md`: nome, autor, link e licença. Se for CC BY, acrescente a linha também no `LICENCA-ARTE.md`.
- Guarde o original em `blender/externos/<id>/` (glTF) e registre o ajuste em `importar_externos.py`.

## Antes de dar por pronto

1. Olhe o modelo pelo Blender MCP (print) ou exporte e tire a foto no jogo, perto e de longe.
2. Compare com fotos de referência do objeto real (mangue-vermelho, caranguejo-uçá, rede maranhense etc.).
3. Confira escala (porta ~2 m, balde ~30 cm), origem no chão e se a sombra aparece.
4. Rode `--teste` (skill `rodar-e-testar`) para ter certeza de que colisão e posição não quebraram a missão.
