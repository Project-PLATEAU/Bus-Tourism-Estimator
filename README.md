# 観光客交通手段判定(バス) <!-- OSSの対象物の名称を記載ください。分かりやすさを重視し、できるだけ日本語で命名ください。英語名称の場合は日本語説明を（）書きで併記ください。 -->

![概要](./img/tutorial_001.png) <!-- OSSの対象物のスクリーンショット（画面表示がない場合にはイメージ画像）を貼り付けください -->

## 更新履歴
| 更新日時 | リリース | 更新内容 |
| ---- | ---- | ---- |
| 2025/1/17 | 1st Release | 初版リリース |

## 1. 概要 <!-- 本リポジトリでOSS化しているソフトウェア・ライブラリについて1文で説明を記載ください -->
本リポジトリでは、Project PLATEAUの令和6年度のユースケース開発業務の一部であるUC24-05「高精度観光動体システムの社会実装」について、その成果物である「観光客交通手段判定(バス)」のソースコードを公開しています。

「観光客交通手段判定(バス)」は、スマートフォン端末より取得した人流データをもとに、移動ログの交通手段がバスで移動したかどうかを判定するロジックです。

## 2. 「観光客交通手段判定(バス)」について <!-- 「」内にユースケース名称を記載ください。本文は以下のサンプルを参考に記載ください。URLはアクセンチュアにて設定しますので、サンプルそのままでOKです。 -->
「観光客交通手段判定(バス)」では、観光客の観光地への来訪交通手段を把握し、今後の観光施策立案に有効活用することを目的として開発されました。
本ロジックは、スマートフォン端末の移動履歴とバス路線情報やバスの移動履歴情報をもとに、車等または自転車等と判定された移動の中でバスに該当するものを判定しています。
本ロジックは、オープンソースソフトウェアとしてフルスクラッチで開発されています。
本ロジックの詳細については[技術検証レポート](https://www.mlit.go.jp/plateau/file/libraries/doc/plateau_tech_doc_0030_ver01.pdf)を参照してください。

## 3. 利用手順 <!-- 下記の通り、GitHub Pagesへリンクを記載ください。URLはアクセンチュアにて設定しますので、サンプルそのままでOKです。 -->
## 使用方法(サンプル)
1. "input_sample.json"と"ダミープローブデータサンプル.csv"と"長野県バスルートデータサンプル.json"と"長野県メッシュデータサンプル.csv"をそれぞれ`input_sample`,`長野県メッシュデータ`,`ダミープローブデータ`,`長野県バスルートデータ` としてBQ上にテーブルを作成する。
2. バス判定用クエリのテーブル参照の箇所を上記のテーブル名に書き換える。
3.実行するとバス判定が行われpred_tpmodeが更新される。

## 使用方法(実データ)
1.input_sampleとダミープローブデータは実データを用いる。長野県メッシュデータはそのまま用いて良い。一方長野県バスルートデータは一部しかサンプルでは存在しないので長野県バスルートデータ作成用.ipynbを実行することで全域のラインストリング型のデータを作成しこれを用いる。
(ラインストリングからポリゴンを作成する例：st_buffer(st_geogfromtext(geometry), 10))
2.バス判定用クエリのテーブル参照の箇所を上記で用いるテーブル名に書き換える。
3.実行するとバス判定が行われ、pred_tpmodeが更新される。

## 4. ロジック概要 <!-- OSS化対象のシステムが有する機能を記載ください。 -->
### 【判定ロジック】
1.移動手段判定で車もしくは自転車と予測されているセグメントを一旦単体のログに分解した後、バスのプローブデータが取得された時間と近い時間に近い場所にいるユーザーログにバスフラグ1(0-1変数)をつける.
  具体的にはプローブデータの取得時間から30秒前後に、原則accuracyの範囲内、accuracyが300mより大きい場合は300mの範囲内に存在すれば、バスフラグ1を立てる.
2.上記のログのうち、バスの路線ボリゴンに入っているユーザーログにバスフラグ2(0-1変数)をつける.
  具体的にはバスのラインストリングから左右に幅10mをとったポリゴンの中にログが存在すればバスフラグ2を立てる.
3.上記のログを再度セグメントに統合し、5:00:00から22:59:59の間に、同一セグメント内で(バスフラグ1の個数+バスフラグ2の個数)/セグメント内の移動ログの個数>=0.75となった場合そのセグメントの移動手段をバスとする。
4.次に集団移動を考慮する.再度3のセグメントを単体のログに分解した後、近い時間に近い場所にいるユーザーログをjoinする。
  まずログの取得時刻から30秒前後以内に取得されかつaccuracyと100mの最小値の範囲内に存在しているそのid以外のログをjoinする
  その後同じID,セグメントnoで統合した際に近くにいた別のIDの登場回数をカウントする。
  近づき回数が2以上のユーザーが3人以上いたid、セグメントだけを集団移動セグメントとし、このセグメントの移動手段をバスとする。
5.4のテーブルを、移動手段判定で車、自転車以外に予測されたテーブルと結合する。


## 5. 利用技術

| 種別              | 名称   | バージョン | 内容 |
| ----------------- | --------|-------------|-----------------------------|
| ソフトウェア       | [Google Bigquery](https://cloud.google.com/bigquery?hl=ja) |  |コードの実行 |
| ライブラリ      | [Geopandas](https://geopandas.org/en/stable/) |1.0.1 |空間データ（Shapefileなど）の操作や解析を行うためのライブラリ |
| ライブラリ      | [Shapely](https://shapely.readthedocs.io/en/stable/) |2.0.6 |ジオメトリ操作（WKT変換、空間演算など）を行うためのライブラリ |


## 6. 動作環境 <!-- 動作環境についての仕様を記載ください。 -->
| 項目               | 最小動作環境                                                                                                                                                                                                                                                                                                                                    | 推奨動作環境                   |
| ------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------ |
| OS                 | Microsoft Windows 10 または 11                                                                                                                                                                                                                                                                                                                  |  同左 |
| CPU                | Intel Core i3以上                                                                                                                                                                                                                                                                                                                               | Intel Core i5以上              |
| メモリ             | 4GB以上                                                                                                                                                                                                                                                                                                                                         | 8GB以上                        |
| ディスプレイ解像度 | 1024×768以上                                                                                                                                                                                                                                                                                                                                    |  同左                   |
| ネットワーク       | 【判定ロジック実行】インターネット環境へ接続されていることが必要【|  同左                            |

## 7. 本リポジトリのフォルダ構成 <!-- 本GitHub上のソースファイルの構成を記載ください。 -->
| フォルダ名 |　詳細 |
|-|-|
| input | インプットデータが含まれているフォルダ |
| query | バス判定ロジック |
| output | 出力結果のサンプル |



## 8. ライセンス <!-- 変更せず、そのまま使うこと。 -->

- ソースコード及び関連ドキュメントの著作権は国土交通省に帰属します。
- 本ドキュメントは[Project PLATEAUのサイトポリシー](https://www.mlit.go.jp/plateau/site-policy/)（CCBY4.0及び政府標準利用規約2.0）に従い提供されています。

## 9. 注意事項 <!-- 変更せず、そのまま使うこと。 -->

- 本リポジトリは参考資料として提供しているものです。動作保証は行っていません。
- 本リポジトリについては予告なく変更又は削除をする可能性があります。
- 本リポジトリの利用により生じた損失及び損害等について、国土交通省はいかなる責任も負わないものとします。

## 10. 参考資料 <!-- 技術検証レポートのURLはアクセンチュアにて記載します。 -->
- 技術検証レポート: https://www.mlit.go.jp/plateau/file/libraries/doc/plateau_tech_doc_0030_ver01.pdf
- PLATEAU WebサイトのUse caseページ「カーボンニュートラル推進支援システム」: https://www.mlit.go.jp/plateau/use-case/uc22-013/
