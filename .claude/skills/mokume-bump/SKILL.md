---
name: mokume-bump
description: "mokume の新しい版に works の作品を追随させるときに読む。版上げ・新しい語彙での書き直し・mokume への起票までの順序と、版上げでだけ踏む落とし穴。Use when mokume releases a new version, when a mokume watch issue is filed, when running scripts/bump.py, or when a work's Package.resolved is behind."
---

# mokume の版上げに追随する

**分岐と落とし穴だけを持つ。** 何をどう見るかは各作品の README と `scripts/` にある。

**物差し (Atlas・Probe・Drift) は [probes](https://github.com/mokume-metal/probes) へ移した。**
あちらの版上げは probes の `probes-bump` スキルが持つ。

## まず見る

```bash
python3 scripts/status.py      # どの作品が遅れているか・道具の版
python3 scripts/api-diff.py    # 何が消え、何が通らなくなり、何が増えたか
python3 scripts/upstream.py    # 戻した Issue がどうなったか
```

**リリースノートから始めない。** `v0.6.0` の `## 破壊的変更` に載っていたのは 2 件で、
`## 新機能` の中に太字で 2 件が埋まり、残り 4 件はノートに 1 度も出てこなかった。
`api-diff.py` は**署名 1 行**を単位に見るので、名前が同じまま型だけ変わったもの
(`isKeyDown(_ code: Int)` → `(_ key: Key)`) も出る。

**当たりは Swift だけで探さない。** README も mokume の口を名指しで持っている。
[#21](https://github.com/mokume-metal/works/issues/21) が「該当ゼロ件」と誤ったのは
Swift しか見なかったためで、実際は (当時 works にあった Atlas の) 台帳が触れていた
([#30](https://github.com/mokume-metal/works/issues/30))。

## 順序 — 2 つに分ける

| | PR | なぜ分けるか |
| --- | --- | --- |
| ① | `build:` 版だけ上げる。**中身は 1 行も変えない** | ここで基準線を取るから、②で絵が動いたときに「版差か書き直しか」を言い切れる。**作品は指紋を持たないので目で見る比較になり**、なおさら混ぜられない |
| ② | `refactor:` 埋まった穴を使って書き直す | |

根拠は作品自身が書いている — `Helmet/README.md` の「**絵が動くので、版を上げる変更に
混ぜない**」。①と②を混ぜると、この切り分けができなくなる。

```bash
python3 scripts/bump.py 0.7.0      # ① Package.swift と Package.resolved (全作品)
```

**絵が動いたかどうかは、窓を開けて目で見る。** works は指紋を持たない — 作品は計測も
検証も持たない ([#40](https://github.com/mokume-metal/works/pull/40))。
気付いたことは各 README の散文へ書く。

## 作品ごとに並行させる

作品はフォルダで分かれているので、**同じ worktree のままサブエージェントを作品ごとに
立ててよい**。ただし:

- **git を触るのはメインだけ。** サブエージェントには確認と README の散文だけを任せる

## 版上げでだけ踏む落とし穴

### README を書き換えるとき

- **`vN.N.N` を一括置換しない。** README 全体で 100 箇所あるが、大半は「`v0.5.0` では
  こうだった」という**歴史の記録**である
- **版入りの見出しは追記する。書き換えない。** `Grain` が
  `### 版を上げたときに動いたもの — v0.1.0 相当 → v0.5.0` と `— v0.5.0 → v0.6.0` を
  両方残しているのがその形。書き換えると、他の作品から張られたアンカーも切れる
  (`Ring` と `Solids` が `Garden` の見出しを指している)
- 作品の README は「どの mokume で描いたか」を手書きで 1 行持つ。版上げで書き換える

### 絵の貼り替え

手貼りの絵は 2 種類あり、**扱いが逆**である。

| | 版上げで |
| --- | --- |
| **いまの絵** (各 README の先頭) | 絵が動いたら貼り替える |
| **歴史の証跡** (「以前はこうだった」) | **貼り替えてはいけない** |

`Grain` が「貼ってあったのは 2 版ぶん古い絵だった」と記録している。**作品では動いたことを
機械が言わない**ので、版を上げたら必ず窓を開けて先頭の絵と見比べる。撮り方は repo-standards の `gyazo-capture` スキル。

### 走らせると副作用が出ることがある

**版が上がると増える。** `v0.6.0` で押下を受け取れるようになった結果、当時 works にあった
`Atlas --motion` が `SaveOneImage` の例を押して `line.png` を書き出すようになった。
スケッチが自分で書き出すことはあるので、**手で走らせたら `git status` を見て、未追跡のファイルが
増えていないか確かめる**。

## mokume へ戻す

判断の表はルート README にある (できない → `Feature` / 期待と違う → `Bug`)。
ADR-0022 決定 3 が求めるのは本文に「**どの作品で・何を作ろうとして・何ができなかったか**」
と works へのリンク 1 本。

**閉じた Issue は表から消さない。** 何を踏んで、どの版で塞がったかは記録である。
`upstream.py --stale` が書き戻し漏れを出す。

## 済んだら

- ルート README の作品一覧と「全 N 作品が mokume `vX.Y.Z` を引いている」の行
- `python3 scripts/upstream.py --stale` が黙ること
