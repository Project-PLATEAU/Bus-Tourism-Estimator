# 操作マニュアル

# 1 本書について

本書では、「バス移動判定クエリ」の動作手順について記載しています。

# 2 使い方
①inputフォルダ内に存在する以下のサンプルデータをダウンロードしてください。<br>
- input/input_sample.json<br>
- input/ダミープローブデータサンプル.csv<br>
- input/長野県バスルートデータサンプル.json<br>
- input/長野県メッシュデータサンプル.csv<br>

②上記のデータをBigQueryの任意のデータセットにアップロードしてください。<br>

③query/バス判定用クエリのテーブル参照の箇所を上記のテーブル名に書き換えます。<br>

④BigQuery上でクエリを実行するとoutputフォルダ内にある出力結果が表示されます。<br>

# 3 入力データについて
## (1)input_sample.json
### 概要
input_sample.jsonは人流データのログを滞在か移動(鉄道、自動車等、自転車等、徒歩)に分類したデータです。本OSSでは、ダミーデータを用いています。<br>
[ネスト構造](https://cloud.google.com/bigquery/docs/best-practices-performance-nested?hl=ja)になっているため、BigQuery上での操作が必要です。

### テーブルスキーマ
| カラム名 | 意味 |
|:-----------|------------:|
| common_id                  | 端末の固有ID                           |
| seq_no                     | シーケンスno                           |
| is_uuid                    | UUIDフラグ                            |
| os                         | スマートフォンOS                        |
| arrive_ptime               | 滞在開始時間                           |
| depart_ptime               | 滞在終了時間                           |
| visiting_second            | 滞在時間                              |  
| cnt                        | 滞在の場合のログ数                      | 
| is_stay                    | 滞在フラグ                             | 
| raw_array.latitude         | 緯度                                  |
| raw_array.longitude        | 経度                                  |  
| raw_array.sdk_detect_ptime | ログ検知時刻                           | 
| raw_array.accuracy         | ログ検知誤差                           | 
| raw_array.latitude         | 緯度                                  | 
| pred_tpmode                | 移動手段(鉄道、自動車等、自転車等、徒歩)    | 

## (2)ダミープローブデータサンプル
### 概要
ダミープローブデータはバスの移動情報を取得したデータです。本OSSでは、ダミーデータを用いています。
### テーブルスキーマ
| カラム名 | 意味 |
|:-----------|------------:|
| id                | 車両ID                         |
| type              | 車両種別                          |
| OD                    | 出庫/経路/入庫                           |
| numbering                         | 個別データ連番                      |
| date_time               | 時刻                           |
| Lon               | 緯度                          |
| Lat            | 経度                              |  
| speed                        | 速度                      | 
| direction                    | 方向                            | 
| 3rd_mesh         | 3次メッシュ番号                                  |
## (3)長野県バスルートデータサンプル
### 概要
国土数値情報より取得したバスの路線情報を示したデータです。
### テーブルスキーマ
| カラム名 | 意味 |
|:-----------|------------:|
| N07_001                 | バス事業者名                           |
| N07_002                     | その他特記事項                          |
| geometry                    | 路線のポリゴン                            |

## (4)長野県メッシュデータサンプル
### 概要
長野県内の125mメッシュコードを示したデータです。
| カラム名 | 意味 |
|:-----------|------------:|
| mt_mesh                 | 長野県の125mメッシュコード                           |



# 4 出力データ
クエリを実行すると、バス判定がなされ、以下のスキーマに従ってデータが抽出されます。
## 出力データのテーブルスキーマ
| カラム名 | 意味 |
|:-----------|------------:|
| common_id                  | 端末の固有ID                           |
| seq_no                     | シーケンスno                           |
| is_uuid                    | UUIDフラグ                            |
| os                         | スマートフォンOS                        |
| arrive_ptime               | 滞在開始時間                           |
| depart_ptime               | 滞在終了時間                           |
| visiting_second            | 滞在時間                              |  
| cnt                        | 滞在の場合のログ数                      | 
| is_stay                    | 滞在フラグ                             | 
| raw_array.latitude         | 緯度                                  |
| raw_array.longitude        | 経度                                  |  
| raw_array.sdk_detect_ptime | ログ検知時刻                           | 
| raw_array.accuracy         | ログ検知誤差                           | 
| raw_array.latitude         | 緯度                                  | 
| pred_tpmode                | 移動手段(鉄道、自動車、バス、自転車、徒歩)    | 

# 5 注意点
本判定ロジックの精度はブログウォッチャー社がスマホアプリユーザーから許諾を受け収集している位置情報データを用いて検証されています。他データベンダーのデータであってもテーブルスキーマを満たせば判定は可能ですが、精度が担保できない恐れがあります。