# 工業団地データ収集・照合監査

調査日：2026-09-10

**取得対象とした一覧の全行保存は完了。全国の設立済み工業団地の完全網羅と、全件の位置確認は未完了。**

## 件数と残作業

| 出典 | 取得した記録 | 地図への照合済み | 未照合 | 照合先の異なる地点数 |
|---|---:|---:|---:|---:|
| Invest Vietnam政府地図フィード | 391 | 124 | 267 | 111 |
| KCN-KKT発見用一覧 | 1,260 | 171 | 1,089 | 160 |
| 合計（重複を含む出典行） | 1,651 | 295 | 1,356 | 出典間で重複あり |

政府フィード391件の詳細ページも391件取得し、所在地欄を抽出した。
両一覧には同一団地の重複、拡張・段階別の記録、計画案件、CCN、特殊区域が含まれる。
したがって未照合1,356行は「未収集の団地1,356件」ではない。
位置の分からない行は削除せず、座標を欠損のまま保持した。

地図データは429地点：KCN/KCX 306、CCN 118、ハイテクパーク5。
KCN/KCXは286ポリゴン、20代表点。同期直後のmainの422地点から7地点増加した。
現在の34省に加え、所在地未確定を独立区分として、出典別の未照合数を
`industrial-park-source-province-coverage.csv` に保存した。

全国478件という既存の参照値と306地点との差172は、未収集件数として使えない。
名簿の時点、法的設立状況、区域区分、段階別の数え方が揃っていないためである。
監査指標名を `arithmetic_difference_not_verified_missing` に変更した。
2026年7月の政府機関の記事も478件を**2025年末**の値として説明しており、
2026年9月現在の全件名簿を検証した値ではない。
[政府機関による説明](https://asemconnectvietnam.gov.vn/default.aspx?ID1=1&ID8=149967&ZID1=45)

## 追加した地点

- KNIC Đông Long Thành：開発会社がXuân Quế–Sông Nhạn工業団地との対応を明示。
  既存OSMポリゴンを採用。
  [開発会社の2026年8月4日付記事](https://knic.com.vn/vi/knic-dong-long-thanh-ra-quan-tong-thau-ha-tang-mo-rong-khong-gian-san-xuat-tren-hanh-lang-kinh-te-phia-dong/)
- Mỹ Hiệp：OSM名称の誤記により分類から漏れていたCCN。省商工局の資料で確認。
  [Đồng Tháp省商工局](https://dongthap.gov.vn/web/sctdt/tin-tuc/chi-tiet?id=2695008)
- Du Long、Sa Đéc、Thạnh Phú、Nhân Cơ、Nam Pleiku：政府名簿と省情報、
  既存作業ブランチのOSM参照地点を照合し、所在地の代表点として追加。
  入口・内部道路等からの位置であり、団地境界を確認済みという意味ではない。
  全OSM参照IDと元の観測日を保持し、再照合日と区別した。

## 誤座標・誤判定への対処

政府フィードの座標あり120行は、所在地として特定した省との整合が82行、
不一致14行、省情報不足等で比較できないもの24行だった。不一致は要確認であり、
所在地テキスト側の誤りもありうる。報告座標は保存するが、そのまま採用しない。
例えば[Đại Kim](https://investvietnam.gov.vn/vi/kcn.pd/bac-ninh---kcn-dai-kim.html)
は所在地説明がBắc Ninhを指す一方、フィードの座標はHà Nội側になる。
同ページの説明本文には別団地の文章も混入している。

道路の目的地や近隣都市の名前を所在地として扱わない。
Bình Phúの交通説明にHà Nộiが現れることだけで同名のHà Nội地点へ結び付けない
回帰テストを追加した。所在地が不明な場合、発見用一覧で名称が一意に一致する
省を補助的に参照し、`province_source_url` と `province_match_method` に明記する。
これも法的設立状況の検証にはならない。

OSMの `landuse=industrial` だけから操業中と推定していた処理を修正した。
こうした行のstatusは `unknown` とし、明示的な建設タグは別に扱う。
出典一覧の `legal_status` は `not_verified` を維持する。

## 収集・照合方法

- [Invest Vietnam地図](https://investvietnam.gov.vn/vi/khu-cong-nghiep.pl.html)：
  公開JSONフィード全行とリンク先の所在地欄。欠損座標 `(0,0)` を使用しない。
- [KCN-KKT一覧](https://kcn-kkt.com/kcn)：ページに埋め込まれた全1,260行から
  名称・省・所在地等の事実情報とリンクを保存。運営上の価格推定等は採用しない。
  計画案件を含む発見用一覧で、法的な確定名簿として使用しない。
- OSM：mainの2026-08-31地図を保持。旧ブランチの追加候補は所在地の代表点に
  限定し、古い境界ポリゴンを最新mainへ上書きしない。
- ベトナム語表記、ローマ数字、既存別名を正規化して照合。段階・拡張語を無差別に
  除去しない。同じ省・区分の近接地点との二重登録を避ける。
- 未照合行のうち同名の地図候補がある場合は `candidate_map_ids` に記録する。
  候補だけでは採用せず、全未照合行を `industrial-park-unresolved.csv` に残す。

## Gitの状態と保存した旧作業

- 開始時main：`454f06b`。未コミット作業が3追跡ファイルと複数の新規ファイルに存在。
- `git fetch origin` 後、最新main `e463579da28e906747c1f55afcaa2797043b139b`
  へfast-forward。mainと取得済みorigin/mainのコミットは一致。
- 旧作業は未追跡ファイルも含め、stash
  `9ebb330b5509ca02e424df5e5765503def15bb80` に保存。削除・popしていない。
- 未統合ブランチ `claude/vietnam-industrial-park-mapping-awtavr` の
  `29cc12f` から309行の名簿を保存して照合に使用。
  ブランチ全体を上書き統合せず、mainの後続更新を維持した。
- 旧Invest Vietnam作業391行も `source/industrial-park-evidence/` に保存。
  同名データオブジェクトと最新関数の衝突を避け、旧Rコードはstashに保持した。
- 今回の追加・修正は作業ツリーに存在する。コミット・pushは行っていない。

## 成果物と再現方法

- `industrial-park-sources.csv`：出典ごとの全1,651行。
- `industrial-park-unresolved.csv`：未照合1,356行。重複を含む。
- `industrial-park-source-province-coverage.csv`：省別・出典別の残件数。
- `../output/industrial-parks/mapped-sites.csv`：地図429地点、WGS84座標と出典。
- `../output/industrial-parks/industrial-parks.geojson`：ポリゴン・代表点のGISデータ。
- `../output/industrial-parks/industrial-parks-map.png`：区分別の分布図。
- `../output/industrial-parks/coordinate-conflicts.csv`：報告座標と省の不一致14行。

`README.md` の手順でオフライン再構築できる。出典ファイルのSHA-256を
`source/industrial-park-evidence/manifest.csv` に記録した。
収集スクリプトは詳細取得の失敗を黙って無視しない。

検証：391ページの所在地抽出を2通りのパーサーで照合、一致。
パッケージ全テストと工業団地の最終テストを通過。
主要RDS/CSVは連続したオフライン再構築でバイト単位一致。
Rパッケージのインストールと、sf非依存の一覧APIを確認。
GeoJSON/CSV出力と地図PNGの描画・目視確認を実施した。

## 全国完全網羅のために残る作業

267行の政府記録と1,089行の発見用記録について、個別の名称・所在地・重複・
段階・法的区分を省管理委員会の資料や設立決定、事業者資料で解決する必要がある。
全34省で同じ時点・範囲の設立済みKCN一覧を取得し、現行の地図地点との対応を
一件ずつ確定するまで、「全国の残りは172件」「全件網羅済み」とは判断できない。
この作業は未完了であり、収集済みの全行と未解決行を残すことで追跡可能にした。

## このMacで確認した実行環境

既定のR 4.6にはsfがなく、R 4.5のライブラリをR 4.6へ混ぜると読み込みに失敗した。
R 4.5本体とそのライブラリを組み合わせて、再構築とテストを実行した。
既定Rの設定やグローバルライブラリは変更していない。このMacで地図を再出力するには：

```sh
R_HOME=/Library/Frameworks/R.framework/Versions/4.5-arm64/Resources \
  /Library/Frameworks/R.framework/Versions/4.5-arm64/Resources/bin/exec/R \
  --vanilla --slave -f tools/build-industrial-park-map.R
```

全出典一覧の読み出しにはsfが不要なため、既定R 4.6でもインストールと一覧APIを検証済み。
