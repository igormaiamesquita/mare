# MARÉ — sobrevivência no mangue

Jogo de sobrevivência em primeira pessoa num manguezal brasileiro. A comida está na lama, e quem manda no relógio é a maré.

Feito com **[Godot 4.7](https://godotengine.org)** e **[Blender](https://www.blender.org)**, em português, e aberto para a comunidade ajudar a construir.

## O que tem hoje

- Mangue do Maranhão com maré gigante que sobe e desce duas vezes por dia, maré de lua, dia e noite, chuva e temporal
- Pegar caranguejo na toca (enfiar o braço, agarrar na hora certa, puxar com jeito) — e o caranguejo tem cérebro: foge, se esconde e se defende
- Aratu nas raízes na maré cheia, peixe nas poças da vazante, tarrafa no cardume
- Lama mole que atola, arraia na água rasa, muriçoca ao entardecer, fome, força e saúde
- Fogão de 3 pedras, jirau-fogão de pau e lama que você constrói em qualquer lugar
- Mochila e balde, mapa, bússola, tábua de marés
- Missões: **Caranguejo com Cérebro** e **Parabólica na Lama** (consertar uma canoa com rabeta e atravessar a baía)
- Homenagens ao mangue beat: parabólica fincada na lama, palafita, nomes misturando Maranhão e Pernambuco
- Jogo salvo automático

## Como jogar

1. Instale o [Godot 4.7](https://godotengine.org/download) (no Mac: `brew install --cask godot`).
2. Baixe este repositório e rode:
   ```bash
   godot --path jogo
   ```
   Ou abra a pasta `jogo/` pelo Godot e aperte **F5**.

Teclas e detalhes em [`jogo/LEIA-ME.md`](jogo/LEIA-ME.md).

## Estrutura

- `jogo/` — o projeto Godot (cenas, scripts, shaders, modelos `.glb` e texturas)
- `blender/gerar_assets.py` — modela e exporta os objetos feitos para o jogo
- `blender/importar_externos.py` — adapta modelos livres de terceiros (`blender/externos/`)

## Contribuir

Veja [`CONTRIBUINDO.md`](CONTRIBUINDO.md).

## Licença

Código sob **MIT**. Arte própria sob **CC BY 4.0**. Arte de terceiros **CC0** (Poly Haven). Detalhes em [`LICENCA-ARTE.md`](LICENCA-ARTE.md).
