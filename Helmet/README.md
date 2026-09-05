# Helmet — Khronos の DamagedHelmet を mokume へ

![絵を貼らずに置いた兜 (frame 200)](https://i.gyazo.com/74b2111cc233ffa5176952f501d39786.png)

制作トラック ([mokume ADR-0022](https://github.com/mokume-metal/mokume/blob/main/docs/decisions/0022-production-track.md)) の 6 本目。

目標は three.js の [webgl_loader_gltf](https://threejs.org/examples/#webgl_loader_gltf) 相当 — glTF を読んで PBR マップ 5 枚と HDR 環境で見せる絵 — だったが、**絵を 1 枚貼るところで止まった** ([mokume#914](https://github.com/mokume-metal/mokume/issues/914))。上の絵は絵を貼らずに置いたもので、形は出ている。

折れたことは失敗ではなく、この作品の成果物である。ADR-0022 決定 4 が言うとおり「作ろうとして止まる」が最も純度の高い実需で、止まった瞬間のほうが何が無かったかを正確に指せる。

**止まった原因は mokume 側で直った** ([mokume#914](https://github.com/mokume-metal/mokume/issues/914) は閉じ、main の `81efdf2` に入っている)。**まだ配られていない**ので、この作品が固定している `v0.5.0` では下の 3 枚目のままである。段 3 以降へ進むには、引く版を上げるのが先になる。

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

## 走らせる

```bash
mokume run .      # 作って走らせる
mokume watch .    # 保存したら作り直して差し替える
```

書き出しと測定は実行ファイルへ直に渡す (CLI は引数を通さないため)。

```bash
swift run -c release Helmet --render <置き場> <番号>       # 1 枚だけ書き出す
swift run -c release Helmet --frames <置き場> <数>         # 連番で書き出す
swift run -c release Helmet --measure chunked <塊の枚数>   # 組み立ての時間を測る
swift run -c release Helmet --measure whole                # 全部 1 度に渡して測る (終わらない)
```

`--render` は書き出したあと**明るさの分布**を出す。「形が出たか」を目で見る前に数で切り分けられる — 画像を読むのは高い操作なので、まず数で当たりを付ける作りにしてある。

絵が出ないときの切り分けは環境変数で段ごとに潰せる。**この作品では実際に 4 段目で折れた。**

| | 何を試すか |
| --- | --- |
| `HELMET_PROBE=box` | 組み込みの `box(150)` を同じ位置に置く (カメラが合っているか) |
| `HELMET_PROBE=triangle` | 三角形 1 枚をその場で描く (頂点の経路が通るか) |
| `HELMET_PROBE=retained` | 同じ三角形を保持した形として置く |
| `HELMET_PROBE=textured` | 三角形 1 枚に絵を貼って保持した形として置く |
| `HELMET_NOTEXTURE=1` | 兜を絵なしで組む |
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

### 段 1 — 形は出る

| | |
| --- | --- |
| glTF を読む | 10.4 ms |
| 頂点 / 三角形 / 並び | 14,556 / 15,452 / 1 |
| 添字を展開した頂点 | **46,356** (3.2 倍) |
| 読み飛ばした要素 | **0** |
| Shape を組む (塊 32 枚) | 153.1 ms |
| 描画の回数 | 1 |

**添字を渡す口が無いので、頂点が 3.2 倍になる。** glTF は 14,556 頂点を 46,356 の添字で参照するが、mokume の頂点の口は `vertex()` だけなので CPU で展開することになる。`SolidVertex` は 96 バイトなので 4.45 MB を積む。

### 段 2 — 絵を貼ると消える

**ここで折れた。**

| 組み方 | 塗られた画素 | 絵 |
| --- | ---: | --- |
| 絵を貼らない | 63,772 | <img src="https://i.gyazo.com/74b2111cc233ffa5176952f501d39786.png" width="420"> |
| 絵を貼って `draw()` で組み直す | 63,413 | <img src="https://i.gyazo.com/9d3f8cff737613fcd913b77e053cedf1.png" width="420"> |
| 絵を貼って `setup()` で組む | **0** | <img src="https://i.gyazo.com/a454b151e3be7de058645f6cb40906c3.png" width="420"> |

> 撮影範囲: `--render out 200` が書き出した**スケッチの面だけ** (画面は撮っていない)。frame 200・960x540。3 枚とも同じフレーム番号・同じ視点で、違うのは組み方だけである。

3 枚目が症状で、`setup()` で組んだ絵つきの形を `draw()` で置くと **1 画素も描かれない**。46,356 頂点・描画 1 回で組めていることは数で確認できるのに、絵にならない。警告も出ない。

→ [mokume#914](https://github.com/mokume-metal/mokume/issues/914) — **直った** ([mokume#917](https://github.com/mokume-metal/mokume/pull/917))。`place` が記録した面へ切り替えたあと、`beginSolids()` の `useFillTexture()` が**置く側の**状態で面を選び直して焼き場へ倒していた。「直後に置くと描かれる」の非対称も、`createShape` が `openSource` を `.solid` のまま抜けることから来ていた

**直ったことは、この作品で確かめてある。** `Package.swift` を mokume の直しのブランチへ一時的に向けて走らせたら、`setup()` で組んだ絵つきの形が `draw()` で描かれた — 塗られた画素が **0 → 63,413**、明るさの種類が **1 → 256**。その絵は上の 2 枚目 (`draw()` で組み直したもの) と**バイト単位で同一**だった。

**2 枚目が暗いのも所見である** (画素値の最頻値が 2〜6)。段 3 で追う予定だが、いま追えない。

### 段 3 以降はまだ測っていない

法線マップ・metallicRoughness・AO・emissive・HDR 環境・ACES は、**絵が 1 枚も安定して貼れないと測れない**。[mokume#914](https://github.com/mokume-metal/mokume/issues/914) は直ったので進めるが、**引く版を上げるのが先**である (直しは main にしか無く、この作品は `v0.5.0` に固定している)。

NormalTangentTest と HDRI は取得スクリプトが取ってくるが、まだ 1 度も読んでいない。

## three.js / glTF との対応

| three.js / glTF | mokume | |
| --- | --- | --- |
| `GLTFLoader` | **無い** | 作品側に書いた ([`GLTF.swift`](Sources/Helmet/GLTF.swift) 351 行)。`loadModel` は拡張子で OBJ 以外を弾き、`Model` / `SolidMesh` は internal なので外から組めない |
| POSITION / NORMAL / TEXCOORD_0 | `vertex(x,y,z,u,v)` + `normal()` | 通る |
| `indices` | **無い** | CPU で展開して 3.2 倍に |
| `node.rotation` (四元数) | **無い** (`applyMatrix()` が無く、`Placement` は一様な倍率とオイラー角だけ) | CPU で畳んだ。DamagedHelmet は X 軸 −90° の 1 つなので `rotateX` でも書けるが、一般の glTF は書けない |
| `TANGENT` | **無い** (頂点の口は位置・法線・読み取り位置の 3 つ) | DamagedHelmet 自身も持たないので、実行時に作る必要がある。段 3 |
| `baseColorTexture` | `texture(_:)` | 貼れる。**保持した形では次のフレームで消えていた**が直った ([#914](https://github.com/mokume-metal/mokume/issues/914))。引く版を上げれば効く |
| `normalTexture` / `metallicRoughnessTexture` / `occlusionTexture` / `emissiveTexture` | **無い** | 材質は `shininess` / `metalness` / `ambient` / `emissive` の 4 つで、どれも面ぜんたいに 1 つ。段 3 |
| UV の `REPEAT` ラップ | **無い** (`clamp_to_edge` 固定) | DamagedHelmet の v は **1.26 まで行く**。glTF では普通のことで、繰り返しを前提に展開されている |
| `scene.environment` (HDR) | `Surroundings` は 3 色帯 | 段 6 |
| `ACESFilmicToneMapping` | `clip` / `roll` | 段 7 |
| `antialias: true` | **無い** | [#905](https://github.com/mokume-metal/mokume/issues/905) |
| `OrbitControls` | `orbitControl()` | そのまま当たる |

## 詰まらなかったが、違うところ

- **`v0.5.0` には数を 3 つ並べる色の口が無い。** `fill(255, 255, 255)` も `background(18, 18, 22)` も通らず、`.opaque(red:green:blue:)` (線形) か `.display(red:green:blue:)` (表示値) を書く。`Solids` が「数値 1 つの灰色が書けない」と記録したのと同じ形で、こちらは 3 つでも書けなかった。**`.linear(...)` も無い** — 最新の面を見て書くと通らないので、作品が固定している版の面を見る必要がある
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
| [`main.swift`](Sources/Helmet/main.swift) (書き出しと測定の口) | 52 | 80 |
| [`scripts/fetch.py`](scripts/fetch.py) (資産を取る) | 123 | 168 |

**`GLTF.swift` の 351 行が、そのまま「mokume に glTF リーダーが無い」ことの大きさである。** mokume の OBJ パーサ (`ModelFile.swift`) が 213 行なので、その 1.6 倍を作品側に書いたことになる。ただし読めるのは最小のサブセット (POSITION / NORMAL / TEXCOORD_0 / 添字 / TRIANGLES / node の階層 / 材質の参照) だけで、GLB の容器・sparse accessor・拡張・アニメーションは読まない。

**書き出しの口を写すのは、これで 5 度目である。** `main.swift` の `--render` / `--frames` は Ring から写した。Ring は Solids から、Solids は Garden から、Garden は Grain から写している。

## mokume へ戻したもの

**閉じた版も消さずに残す** ([works#7](https://github.com/mokume-metal/works/issues/7) が名指しした失敗モード — mokume 側が直ったのに README が追随せず、次のセッションが既に塞がった穴を避けて設計してしまう)。

| 踏んだもの | | 状態 |
| --- | --- | --- |
| 絵を貼った保持した形を、次のフレームで置くと消える | [mokume#914](https://github.com/mokume-metal/mokume/issues/914) | **閉じた** ([mokume#917](https://github.com/mokume-metal/mokume/pull/917) / main の `81efdf2`)。まだ配られていないので、この作品が引く `v0.5.0` では再現する |
| 頂点を並べて作る形が、1 度に渡す三角形の数に比例して遅くなる | [mokume#915](https://github.com/mokume-metal/mokume/issues/915) | open |

段 3 以降で踏むものは、引く版を上げてから戻す。
