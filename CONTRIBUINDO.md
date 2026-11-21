# Como ajudar

Toda ajuda é bem-vinda: código, modelos 3D, texturas, som, testes, ideias e pesquisa sobre o mangue.

1. Abra uma *issue* contando o que quer fazer (ou pegue uma aberta).
2. Faça um *fork*, trabalhe num *branch* e abra um *pull request*.
3. Antes de mandar, rode o teste automático (joga a missão inteira sozinho):
   ```bash
   godot --headless --path jogo -- --teste
   ```
   Ele tem que terminar com `TESTE OK`.

## Regras do projeto

- **Obra original.** O jogo se inspira no modo de vida de quem vive do mangue, mas não usa nome, imagem, voz ou bordões de pessoas reais.
- **Só material livre.** Arte de terceiros só com licença CC0 ou CC BY, com o crédito no `CREDITOS.md` da pasta.
- **Português** nos textos do jogo e nos nomes do código.
- **Desempenho:** o jogo precisa rodar a 60 quadros por segundo num computador comum. Objetos com muitos milhares de faces precisam ser simplificados (veja `blender/importar_externos.py`).

## Ideias abertas

- Árvores de mangue mais realistas (raízes-escora, folhas)
- Modelos de caranguejo, siri, rede de dormir e mãos em primeira pessoa
- Som: maré, chuva, passarinhos, muriçoca
- Pesca com linha e curral, turu, ostra
- Coisas para fazer na ilha
- Outros cenários de mangue (Pernambuco, Pará, Bahia)
