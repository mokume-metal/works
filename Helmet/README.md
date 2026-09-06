# Helmet — Khronos の DamagedHelmet を mokume へ

![絵を貼らずに置いた兜 (frame 200)](https://i.gyazo.com/74b2111cc233ffa5176952f501d39786.png)

制作トラック ([mokume ADR-0022](https://github.com/mokume-metal/mokume/blob/main/docs/decisions/0022-production-track.md)) の 6 本目。

目標は three.js の [webgl_loader_gltf](https://threejs.org/examples/#webgl_loader_gltf) 相当 — glTF を読んで PBR マップ 5 枚と HDR 環境で見せる絵 — だったが、**絵を 1 枚貼るところで止まった** ([mokume#914](https://github.com/mokume-metal/mokume/issues/914))。上の絵は絵を貼らずに置いたもので、形は出ている。

折れたことは失敗ではなく、この作品の成果物である。ADR-0022 決定 4 が言うとおり「作ろうとして止まる」が最も純度の高い実需で、止まった瞬間のほうが何が無かったかを正確に指せる。

**止まった原因は mokume 側で直り、`v0.6.0` で配られた** ([mokume#914](https://github.com/mokume-metal/mokume/issues/914) → [mokume#917](https://github.com/mokume-metal/mokume/pull/917))。この作品は `v0.6.0` を引くように上げてあるので、いまは絵が貼れる。**段 3 以降 (PBR マップ・HDR 環境・ACES) はまだ測っていない。**

## 何を測るか

Garden・Solids・Ring が測ったのは p5.js の**語彙の対応**で、Atlas はそれを全数に広げた台帳である。**どれも資産を読まない。** `Solids` が `loadModel()` を通したが、読んだのは自分で書いた 14 面の矢じりで、材質もテクスチャも持たない。

three.js のリッチな 3DCG が実際に使っているのは、語彙ではなく**資産と質感のパイプライン**である。`webgl_loader_gltf` の中身を読むと 5 つ揃っている:

| three.js が使うもの | mokume |
| --- | --- |
| `GLTFLoader` で DamagedHelmet を読む | **無い** (`loadModel` は OBJ だけ) |
| PBR マップ 5 枚 (albedo / metalRoughness / normal / AO / emissive) | 貼れるのは 1 枚 |
| `royal_esplanade_2k.hdr` の equirectangular 環境 | `Surroundings` は上・地平・下の 3 色帯 |
| `ACESFilmicToneMapping` | `clip` / `roll` の 2 種 |
| `antialias: true` | 無い ([mokume#905](https://github.com/mokume-metal/mokume/issues/905)) |

**この 5 つを 1 本で踏めるのが DamagedHelmet を選んだ理由である。** 1 mesh 1 primitive・材質 1 つで、マップだけが 5 枚揃っているので、パイプラインの測定に集中できる。

## 読む資産

**リポジトリにはコミットしない。** どれも第三者の著作物なので、`scripts/fetch.py` が取ってきて `upstream/` (gitignore 済み) へ置き、「どの版のどれを読んだか」を [`sources.json`](sources.json) へ刻む。

```bash
python3 scripts/fetch.py
```

| 資産 | 帰属とライセンス |
| --- | --- |
| [DamagedHelmet](https://github.com/KhronosGroup/glTF-Sample-Assets/tree/main/Models/DamagedHelmet) | CC BY 4.0 (2018, ctxwing — glTF への変換) / CC BY-NC 4.0 (2016, theblueturtle_ — 原型) |
| [NormalTangentTest](https://github.com/KhronosGroup/glTF-Sample-Assets/tree/main/Models/NormalTangentTest) | CC0 1.0 (Analytical Graphics, Inc. / Ed Mackey) |
| [royal_esplanade](https://polyhaven.com/a/royal_esplanade) | CC0 1.0 (Greg Zaal / Poly Haven) |

NormalTangentTest と HDRI は段 3 以降で使うもので、**まだ 1 度も読んでいない**。

## どの mokume で描いたか

**`Package.resolved` が固定している版がそのまま答えで、コミットしてある。** この作品のコミットを checkout すれば mokume も当時の版に戻る。

**同じフレーム番号からは同じ絵が出る** (mokume の [ADR-0001](https://github.com/mokume-metal/mokume/blob/main/docs/decisions/0001-founding-principles.md) 原則 2)。このスケッチは乱数も揺らぎも使わないので、姿勢はフレーム番号だけで決まる。

## 走らせる

**先に資産を取る** (`python3 scripts/fetch.py`)。取っていないと形が出ない。

```bash
mokume run .      # 作って走らせる
mokume watch .    # 保存したら作り直して差し替える
```

**この作品は release で走らせる。** 46,356 頂点を組むので debug では待たされる。

```bash
swift run -c release Helmet
```

絵が出ないときの切り分けは環境変数で段ごとに潰せる。**この作品では実際に 4 段目で折れた。**

| | 何を試すか |
| --- | --- |
| `HELMET_PROBE=box` | 組み込みの `box(150)` を同じ位置に置く (カメラが合っているか) |
| `HELMET_PROBE=triangle` | 三角形 1 枚をその場で描く (頂点の経路が通るか) |
| `HELMET_PROBE=retained` | 同じ三角形を保持した形として置く |
| `HELMET_PROBE=textured` | 三角形 1 枚に絵を貼って保持した形として置く |
| `HELMET_TEXTURE=small` | 貼る絵を 64x64 の焼いたものへ差し替える |
| `HELMET_REBUILD=1` | `setup()` ではなく `draw()` で組み直して置く |

## 測れたこと

### 段 0 — 頂点を渡す費用

**1 度の `beginShape` / `endShape` に渡す三角形の数に比例して遅くなる。** 総量は同じなので、費用は頂点数ではなく「1 度に渡す量」で決まる (release・46,356 頂点):

| 1 度に渡す三角形 | 塊の数 | 組み立て |
| ---: | ---: | --- |
| 1 | 15,452 | **84.1 ms** |
| 32 | 483 | 335.0 ms |
| 128 | 121 | 1.14 s |
| 512 | 31 | 4.43 s |
| 2048 | 8 | **17.23 s** |
| 4096 | 4 | **280 秒で終わらない** |
| 15,452 (全部 1 度に) | 1 | **300 秒で終わらない** |

素直に書けば最後の行になる。**5 分待っても終わらず、例外も進捗も出ない**ので、書いた側からは固まったように見える。三角形を 32 枚ずつに切る回避を書いた — 連続した `endShape` は同じ列に積まれるので描く回数は 1 回のままで、絵も 1 ビット変わらない。

→ [mokume#915](https://github.com/mokume-metal/mokume/issues/915)

> この表は当時の `--measure` が出した数字である。**測る口も、頂点の渡し方を切り替える口も作品から外した** — works に置くのは普通に作品を作った例なので、道具を測る仕掛けは持たせない。いまのコードは `indexed` の 1 本だけである。

#### `v0.7.0` で塞がった — 回避を外し、番号で渡すようになった

**2 つとも閉じた。** 二乗そのものが消え ([mokume#915](https://github.com/mokume-metal/mokume/issues/915) / [#1001](https://github.com/mokume-metal/mokume/pull/1001))、glTF の番号をそのまま渡す口が入った ([mokume#938](https://github.com/mokume-metal/mokume/issues/938) / [#996](https://github.com/mokume-metal/mokume/pull/996))。

| 渡し方 | 組み立て | mokume へ渡る頂点 | 積む量 |
| --- | ---: | ---: | ---: |
| `indexed` (いまの既定) | 20.5 ms | **14,556** | **1.40 MB** |
| `chunked` (塊 32 枚・回避が要った頃) | 19.4 ms | 46,356 | 4.45 MB |
| `whole` (全部 1 度に展開) | 19.2 ms | 46,356 | 4.45 MB |

**`whole` が 300 秒超から 19 ms になった。** 回避を書く理由が無くなったので、塊に切る既定をやめた。

**`indexed` の値打ちは時間ではなく量である。** 組み立ての時間は 3 通りともほぼ同じ (点を 14,556 回置いて番号を 46,356 回積むのと、点を 46,356 回置くのとで、仕事の量が近い) が、mokume が持ち歩く頂点は **3.2 分の 1** になる。glTF は面と点を別々に持つ形式なので、`indexed` が**読んだものをそのまま渡す**書き方でもある。

**絵は 1 ビットも変わらなかった** — 当時の `--render out 1` / `out 200` のハッシュが 3 通りとも一致した。glTF の番号は「位置 + 法線 + 読み取り位置」の組を指すので、共有しても角ごとの値は変わらない。

### 段 1 — 形は出る

| | |
| --- | --- |
| glTF を読む | 10.4 ms |
| 頂点 / 三角形 / 並び | 14,556 / 15,452 / 1 |
| 添字を展開した頂点 | **46,356** (3.2 倍) |
| 読み飛ばした要素 | **0** |
| Shape を組む (塊 32 枚) | 153.1 ms |
| 描画の回数 | 1 |

> この表も当時の測定である。組み立ての記録を標準出力へ流す仕掛けは作品から外した。

**添字を渡す口が無いので、頂点が 3.2 倍になる。** glTF は 14,556 頂点を 46,356 の添字で参照するが、mokume の頂点の口は `vertex()` だけなので CPU で展開することになる。`SolidVertex` は 96 バイトなので 4.45 MB を積む。

### 段 2 — 絵を貼ると消えていた (`v0.6.0` で直った)

**ここで折れた。** 塗られた画素で測ると、版でこう変わる:

| 組み方 | `v0.5.0` | `v0.6.0` |
| --- | ---: | ---: |
| 絵を貼らない | 63,772 | 63,772 |
| 絵を貼って `draw()` で組み直す | 63,413 | 63,413 |
| 絵を貼って `setup()` で組む | **0** | **63,413** |

| 症状 (`v0.5.0`) | 直った姿 (`v0.6.0`) |
| --- | --- |
| <img src="https://i.gyazo.com/a454b151e3be7de058645f6cb40906c3.png" width="440"> | <img src="https://i.gyazo.com/9d3f8cff737613fcd913b77e053cedf1.png" width="440"> |

> 撮影範囲: 当時の `--render out 200` が書き出した**スケッチの面だけ** (画面は撮っていない)。frame 200・960x540。同じフレーム番号・同じ視点で、**コードは 1 文字も違わない** — 違うのは引いている mokume の版だけである。

`v0.5.0` では `setup()` で組んだ絵つきの形を `draw()` で置くと **1 画素も描かれなかった**。46,356 頂点・描画 1 回で組めていることは数で確認できるのに、絵にならず、警告も出ない。

**`v0.6.0` の絵は、`v0.5.0` で `draw()` の中で組み直したときの絵とバイト単位で同一である** (同じ画像を Gyazo へ上げたら既存の URL が返った)。つまり直しは「消えていたものが出るようになった」だけで、絵を変えていない。

参考用に、絵を貼らない姿も残す (これを出していた `HELMET_NOTEXTURE` も作品から外したので、いま撮り直す手段は無い):

<img src="https://i.gyazo.com/74b2111cc233ffa5176952f501d39786.png" width="440">

→ [mokume#914](https://github.com/mokume-metal/mokume/issues/914) → [mokume#917](https://github.com/mokume-metal/mokume/pull/917)。`place` が記録した面へ切り替えたあと、`beginSolids()` の `useFillTexture()` が**置く側の**状態で面を選び直して焼き場へ倒していた。「直後に置くと描かれる」の非対称も、`createShape` が `openSource` を `.solid` のまま抜けることから来ていた。

**残っていた 1 画素の正体も分かった** — 焼き場 (字形の置き場) の空き区画が白いためである。だから mokume 側の検査は白ではなく縞の絵を貼っている。

**絵が暗いのは別の所見である** (画素値の最頻値が 2〜6)。albedo が暗いのか、色の扱いに何かあるのか、まだ切り分けていない — 段 3 で追う。

### 段 3 以降はまだ測っていない

法線マップ・metallicRoughness・AO・emissive・HDR 環境・ACES は**これから**である。絵が 1 枚貼れるようになったので、進める条件は揃った。

NormalTangentTest と HDRI は取得スクリプトが取ってくるが、まだ 1 度も読んでいない。**絵が暗い**ことも段 3 で追う。

## three.js / glTF との対応

| three.js / glTF | mokume | |
| --- | --- | --- |
| `GLTFLoader` | **無い** | 作品側に書いた ([`GLTF.swift`](Sources/Helmet/GLTF.swift) 351 行)。`loadModel` は拡張子で OBJ 以外を弾き、`Model` / `SolidMesh` は internal なので外から組めない |
| POSITION / NORMAL / TEXCOORD_0 | `vertex(x,y,z,u,v)` + `normal()` | 通る |
| `indices` | **無い** | CPU で展開して 3.2 倍に |
| `node.rotation` (四元数) | **無い** (`applyMatrix()` が無く、`Placement` は一様な倍率とオイラー角だけ) | CPU で畳んだ。DamagedHelmet は X 軸 −90° の 1 つなので `rotateX` でも書けるが、一般の glTF は書けない |
| `TANGENT` | **無い** (頂点の口は位置・法線・読み取り位置の 3 つ) | DamagedHelmet 自身も持たないので、実行時に作る必要がある。段 3 |
| `baseColorTexture` | `texture(_:)` | 貼れる。`v0.5.0` では**保持した形で次のフレームに消えていた**が、`v0.6.0` で直った ([#914](https://github.com/mokume-metal/mokume/issues/914)) |
| `normalTexture` / `metallicRoughnessTexture` / `occlusionTexture` / `emissiveTexture` | **無い** | 材質は `shininess` / `metalness` / `ambient` / `emissive` の 4 つで、どれも面ぜんたいに 1 つ。段 3 |
| UV の `REPEAT` ラップ | **無い** (`clamp_to_edge` 固定) | DamagedHelmet の v は **1.26 まで行く**。glTF では普通のことで、繰り返しを前提に展開されている |
| `scene.environment` (HDR) | `Surroundings` は 3 色帯 | 段 6 |
| `ACESFilmicToneMapping` | `clip` / `roll` | 段 7 |
| `antialias: true` | **無い** | [#905](https://github.com/mokume-metal/mokume/issues/905) |
| `OrbitControls` | `orbitControl()` | そのまま当たる |

## 詰まらなかったが、違うところ

- **数を 3 つ並べる色の口が、`v0.5.0` には無かった。** `fill(255, 255, 255)` も `background(18, 18, 22)` も通らず、`.linear(red:green:blue:)` (線形の 0–1) か `.display(red:green:blue:)` (表示値の 0–1) を書いた。`Solids` が「数値 1 つの灰色が書けない」と記録したのと同じ形で、こちらは 3 つでも書けなかった。**`v0.6.0` で `color(_:_:_:)` (0–255) が入った**ので、いまは 3 つ並べて書ける — **この作品はまだ乗り換えていない** (絵が動くので、版を上げる変更に混ぜない)
- **`v0.5.0` の `.opaque(red:green:blue:)` は、`v0.6.0` で `.linear(red:green:blue:)` に改名された。** 版を上げるときに書き換えたのはこの 5 箇所だけである。**最新の面を見て書くと、作品が固定している版では通らない** — 面は版ごとに見る必要がある (この作品を書き始めたときに 1 度踏んだ)
- **UV は画像の画素で書く** (0…1 ではない)。glTF の値に `image.width` を掛ける
- **`texture()` は `beginShape` より前に呼ぶ。** 後だと `vertex(x,y,z,u,v)` の読み取り位置が黙って捨てられ、焼き場の白い区画を読む
- **`fill()` を置かないと 1 枚も置かれない。** 塗りは原始形ごとに 1 度見られる
- **`noStroke()` を呼ばないと三角形 1 枚ごとに輪郭の帯が出る** (1 枚あたり約 36 頂点なので、46,356 頂点が 165 万頂点になる)
- **縦軸が逆。** glTF は Y 上向き、mokume は Y 下向きなので、位置と法線の y を反転する。`Model.make` が読み込んだモデルに対してやっているのと同じことを、自分で書く
- **法線は頂点ごとに書く。** `normal()` は `beginShape` でリセットされ、書き換えるまで効き続けるので、塊に切ると塊の頭で消える

## 原典と違えたところ

**まだ原典に届いていない。** 段 3 以降 (PBR マップ・HDR 環境・ACES) が [#914](https://github.com/mokume-metal/mokume/issues/914) で止まっているので、いまの絵は「形とベースカラーだけ」である。

読むモデルは原典と同じ DamagedHelmet を使った。`Solids` が第三者のアセットを避けて自分で矢じりを書いたのとは逆の判断で、理由は**測りたいものが資産そのものだから**である — マップ 5 枚が揃っていて TANGENT を持たない実物でないと、パイプラインの欠けが出てこない。

## 書いた量

| | 実質 (コメント・空行を除く) | 全体 |
| --- | ---: | ---: |
| [`GLTF.swift`](Sources/Helmet/GLTF.swift) (glTF を読む) | 351 | 438 |
| [`Helmet.swift`](Sources/Helmet/Helmet.swift) (スケッチ) | 268 | 356 |
| [`main.swift`](Sources/Helmet/main.swift) (スケッチを起動する) | 2 | 3 |
| [`scripts/fetch.py`](scripts/fetch.py) (資産を取る) | 123 | 168 |

**`GLTF.swift` の 351 行が、そのまま「mokume に glTF リーダーが無い」ことの大きさである。** mokume の OBJ パーサ (`ModelFile.swift`) が 213 行なので、その 1.6 倍を作品側に書いたことになる。ただし読めるのは最小のサブセット (POSITION / NORMAL / TEXCOORD_0 / 添字 / TRIANGLES / node の階層 / 材質の参照) だけで、GLB の容器・sparse accessor・拡張・アニメーションは読まない。

**書き出しの口を写すのは、これで 5 度目だった。** `main.swift` が持っていた `--render` / `--frames` は Ring から写したもので、Ring は Solids から、Solids は Garden から、Garden は Grain から写していた。**5 本とも作品から外した** — 上の表の `main.swift` が 3 行なのはそのためである。

## mokume へ戻したもの

**閉じた版も消さずに残す** ([works#7](https://github.com/mokume-metal/works/issues/7) が名指しした失敗モード — mokume 側が直ったのに README が追随せず、次のセッションが既に塞がった穴を避けて設計してしまう)。

| 踏んだもの | | 状態 |
| --- | --- | --- |
| 絵を貼った保持した形を、次のフレームで置くと消える | [mokume#914](https://github.com/mokume-metal/mokume/issues/914) | **閉じた** ([mokume#917](https://github.com/mokume-metal/mokume/pull/917))。`v0.6.0` から効く — この作品はその版を引いている |
| 頂点を並べて作る形が、1 度に渡す三角形の数に比例して遅くなる | [mokume#915](https://github.com/mokume-metal/mokume/issues/915) | **閉じた** ([mokume#1001](https://github.com/mokume-metal/mokume/pull/1001))。`v0.7.0` から効く — **塊に切る回避を外した** |
| 頂点に番号 (添字) を渡す口が無く、14,556 点が 46,356 点に展開される | [mokume#938](https://github.com/mokume-metal/mokume/issues/938) | **閉じた** ([mokume#996](https://github.com/mokume-metal/mokume/pull/996))。`v0.7.0` から効く — `index(_:)` で glTF の番号をそのまま渡すようにした |

段 3 以降で踏むものは、踏んだそのときに戻す。
