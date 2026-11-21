# 第三者の素材

同梱している第三者の素材は、次の字体 2 つだけです。効果音は `tools/gen_sfx.py` で合成した自作の物です。

## Noto Sans JP(画面の字)

- ファイル: `assets/fonts/NotoSansJP-Subset.ttf`(原本を、画面に出す文字だけに絞った物。`tools/subset_font.py` で作る)
- 原本: https://github.com/google/fonts/tree/main/ofl/notosansjp の `NotoSansJP[wght].ttf`(コミット `295d98a7a0c17c68f1341eaeea354e7960ea70d3`)
- 原本の SHA-256: `c2f3b4d463500a2ddcd3849cded1fceeb9fd6d1c32e6cbecd568453ba50fc68f`
- ライセンス: SIL Open Font License, Version 1.1。原文は [`assets/fonts/OFL_NotoSansJP.txt`](assets/fonts/OFL_NotoSansJP.txt)(入手元の `OFL.txt` をそのまま置いた)
- 著作権表示: Copyright 2014-2021 Adobe (http://www.adobe.com/), with Reserved Font Name 'Source'

## Tilt Neon(題字と数字、v0.3.0 から)

- ファイル: `assets/fonts/TiltNeon-Subset.ttf`(原本の傾きの軸を 0 に固め、ASCII の字と ı だけに絞った物。`tools/subset_font.py` で作る)
- 原本: https://github.com/google/fonts/tree/main/ofl/tiltneon の `TiltNeon[XROT,YROT].ttf`(コミット `8b0a1d0f5983c89bc2b93f1b5fb55f9e252744b5`)
- 原本の SHA-256: `c22333dfd1cd14c2a612b36ea1c50ea13e5e9244181e5129a63c944a165823a0`
- ライセンス: SIL Open Font License, Version 1.1。原文は [`assets/fonts/OFL_TiltNeon.txt`](assets/fonts/OFL_TiltNeon.txt)(入手元の `OFL.txt` をそのまま置いた)
- 著作権表示: Copyright 2019 The Tilt Project Authors (https://github.com/googlefonts/Tilt-Fonts)

## 効果音

- ファイル: `assets/sfx/*.wav`(14 個)
- 出どころ: `tools/gen_sfx.py` で合成した自作の音。第三者の素材は使っていない。ライセンスはリポジトリと同じ MIT。
