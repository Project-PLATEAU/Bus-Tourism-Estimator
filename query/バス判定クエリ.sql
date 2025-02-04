-- 1) TEMP FUNCTION の定義
CREATE TEMP FUNCTION double_mod(number1 FLOAT64, number2 FLOAT64)
RETURNS FLOAT64
AS (
  CASE
    WHEN number1 IS NULL OR number2 IS NULL OR number2 = 0 THEN NULL
    ELSE number1 - (number2 * FLOOR(number1 / number2))
  END
);

-- CONVERT_TO_MESH を TEMP FUNCTION として定義
CREATE TEMP FUNCTION convert_to_mesh(latitude FLOAT64, longitude FLOAT64)
RETURNS STRING
AS (
  CONCAT(
    -- 1次メッシュ
    CONCAT(
      CONCAT(
        CONCAT(
          CONCAT(
            CONCAT(
              CONCAT(
                CAST(FLOOR(latitude * 1.5) AS STRING), -- 緯度1次メッシュ
                CAST(FLOOR(longitude) - 100 AS STRING) -- 経度1次メッシュ
              ),
              CAST(FLOOR(double_mod(latitude * 60, 40) / 5) AS STRING) -- 緯度2次メッシュ
            ),
            CAST(FLOOR(double_mod(longitude - 100, 1) * 60 / 7.5) AS STRING) -- 経度2次メッシュ
          ),
          CAST(FLOOR(double_mod(double_mod(latitude * 60, 40), 5) * 60 / 30) AS STRING) -- 緯度3次メッシュ
        ),
        CAST(FLOOR(double_mod(double_mod((longitude - 100) * 60, 7.5), 0.75) / 0.75) AS STRING) -- 経度3次メッシュ
      ),
      -- 1/2次メッシュ
      CAST(
        FLOOR(double_mod(double_mod(double_mod(latitude * 60, 40), 5), 0.5) / 0.25) * 2
        + FLOOR(double_mod(double_mod(double_mod((longitude - 100), 1) * 60, 7.5), 0.75) / 0.375) + 1 AS STRING
      )
    ),
    -- 1/4次メッシュ
    CAST(
      FLOOR(double_mod(double_mod(double_mod(double_mod(latitude * 60, 40), 5), 0.5), 0.25) / 0.125) * 2
      + FLOOR(double_mod(double_mod(double_mod(double_mod((longitude - 100), 1) * 60, 7.5), 0.75), 0.375) / 0.1875) + 1 AS STRING
    ),
    -- 1/8次メッシュ
    CAST(
      FLOOR(double_mod(double_mod(double_mod(double_mod(double_mod(latitude * 60, 40), 5), 0.5), 0.25), 0.125) / 0.0625) * 2
      + FLOOR(double_mod(double_mod(double_mod(double_mod(double_mod((longitude - 100), 1) * 60, 7.5), 0.75), 0.375), 0.1875) / 0.09375) + 1 AS STRING
    )
  )
);

-- 2) convert_to_mesh_9 の定義
CREATE TEMP FUNCTION convert_to_mesh_9(lat FLOAT64, lon FLOAT64)
RETURNS STRING
AS (
  CONCAT(
    CAST(FLOOR(lat * 1.5) AS STRING),
    CAST(FLOOR(lon) - 100 AS STRING),
    CAST(FLOOR(double_mod(lat * 60, 40) / 5) AS STRING),
    CAST(FLOOR(double_mod((lon - 100), 1) * 60 / 7.5) AS STRING),
    CAST(FLOOR(double_mod(double_mod(lat * 60, 40), 5) * 60 / 30) AS STRING),
    CAST(FLOOR(double_mod(double_mod((lon - 100) * 60, 7.5), 0.75) / 0.75) AS STRING)
  )
);
#input_sample.csvを用いてBQ上にテーブルを作成してください。以下input_samle.jsonが中身のテーブルを`input_sample`と定義します。
#長野県メッシュデータサンプル.csvを用いてBQ上にテーブルを作成してください。以下長野県メッシュデータサンプル.csvが中身のテーブルを`長野県メッシュデータサンプル`と定義します。
#ダミープローブデータサンプル.csvを用いてBQ上にテーブルを作成してください。以下ダミープローブデータサンプル.csvが中身のテーブルを`ダミープローブデータサンプル`と定義します。
#長野県バスルートデータサンプル.csvを用いてBQ上にテーブルを作成してください。以下長野県バスルートデータサンプル.jsonが中身のテーブルを`長野県バスルートデータ`と定義します


#まず車と自転車と予測したセグメントをログごとに分割する
with
table_car_or_bike AS (
  SELECT
    common_id, seg_no, is_uuid, os, arrive_ptime, depart_time, visiting_seconds, cnt, mesh, is_stay,
    raw_element.sdk_detect_ptime, raw_element.latitude_anonymous, raw_element.longitude_anonymous, raw_element.accuracy,
    needs_tokuminer_flg, pred_tpmode, purpose_flg
  FROM `input_sample` AS st
  CROSS JOIN UNNEST(st.raw_array) AS raw_element
  WHERE (pred_tpmode = "car" OR pred_tpmode = "bike")
    AND raw_element.latitude_anonymous BETWEEN -90 AND 90
    AND raw_element.longitude_anonymous BETWEEN -180 AND 180
),

table_not_car_bike AS (
  SELECT *
  FROM `input_sample`
  WHERE pred_tpmode != "car" AND pred_tpmode != "bike"
),

/* ★ ここがポイント: dummy_probe_sample と meshdata_sample をJOIN */
dummy_probe_joined AS (
  SELECT
    bus.*,
    -- mesh.mt_mesh など必要なら使える
  FROM `ダミープローブデータサンプル` bus
  JOIN `長野県メッシュデータサンプル` mesh
    ON mesh.mt_mesh = CAST(convert_to_mesh(bus.lat, bus.lon) AS INT64)
  WHERE
    bus.lat IS NOT NULL
    AND bus.lon IS NOT NULL
    AND DATE(TIMESTAMP(bus.date_time, "Asia/Tokyo")) BETWEEN "2024-01-01" AND "2024-01-14"
),

/* ★ ここで table_car_or_bike に LEFT JOIN して busフラグを付与 */
bus_flg_table AS (
  SELECT
    table_car_or_bike.*,
    CASE WHEN bus.id IS NULL THEN 0 ELSE 1 END AS bus_flg
  FROM table_car_or_bike
  LEFT JOIN dummy_probe_joined AS bus
    ON convert_to_mesh_9(bus.lat, bus.lon) = convert_to_mesh_9(table_car_or_bike.latitude_anonymous, table_car_or_bike.longitude_anonymous)
    AND DATE(table_car_or_bike.sdk_detect_ptime, "Asia/Tokyo")
         = DATE(TIMESTAMP(bus.date_time, "Asia/Tokyo"))
    AND TIMESTAMP(DATETIME(table_car_or_bike.sdk_detect_ptime, "Asia/Tokyo")) BETWEEN
      TIMESTAMP(DATETIME_SUB(TIMESTAMP(bus.date_time, "Asia/Tokyo"), INTERVAL 30 SECOND))
      AND TIMESTAMP(DATETIME_ADD(TIMESTAMP(bus.date_time, "Asia/Tokyo"), INTERVAL 29 SECOND))
    AND ST_DWITHIN(
      ST_GEOGPOINT(table_car_or_bike.longitude_anonymous, table_car_or_bike.latitude_anonymous),
      ST_GEOGPOINT(bus.lon, bus.lat),
      LEAST(table_car_or_bike.accuracy, 300)
    )
),

/* 以下、元のロジックと同じ */
bus_flg_cnt_1 AS (
  SELECT
    common_id, seg_no, is_uuid, os, sdk_detect_ptime, latitude_anonymous, longitude_anonymous,
    arrive_ptime, depart_time, visiting_seconds, accuracy, cnt, mesh,
    is_stay, needs_tokuminer_flg, pred_tpmode, purpose_flg,
    MAX(bus_flg) AS bus_flg
  FROM bus_flg_table
  GROUP BY
    common_id, seg_no, is_uuid, os, sdk_detect_ptime, latitude_anonymous, longitude_anonymous,
    arrive_ptime, depart_time, visiting_seconds, accuracy, cnt, mesh,
    is_stay, needs_tokuminer_flg, pred_tpmode, purpose_flg
),

bus_flg_table_v2 AS (
  SELECT
    bft.*,
    CASE WHEN poly.polygon IS NULL THEN 0 ELSE 1 END AS bus_flg_2
  FROM bus_flg_cnt_1 AS bft
  LEFT JOIN `長野県バスルートデータサンプル` AS poly
    ON ST_CONTAINS(ST_GEOGFROMTEXT(poly.polygon),
                   ST_GEOGPOINT(bft.longitude_anonymous, bft.latitude_anonymous))
),
bus_flg_cnt_2 AS (
  SELECT
    common_id,
    seg_no,
    is_uuid,
    os,
    sdk_detect_ptime,
    latitude_anonymous,
    longitude_anonymous,
    arrive_ptime,
    depart_time,
    visiting_seconds,
    accuracy,
    cnt,
    mesh,
    is_stay,
    needs_tokuminer_flg,
    pred_tpmode,
    purpose_flg,
    bus_flg,
    MAX(bus_flg_2) AS bus_flg_2
  FROM bus_flg_table_v2
  GROUP BY
    common_id, seg_no, is_uuid, os, sdk_detect_ptime, latitude_anonymous, longitude_anonymous,
    arrive_ptime, depart_time, visiting_seconds, accuracy,cnt, mesh,
    is_stay, needs_tokuminer_flg, pred_tpmode, purpose_flg, bus_flg
),
bus_flg_sum AS (
  SELECT
    common_id,
    seg_no,
    SUM(bus_flg) AS bus_cnt,
    SUM(bus_flg_2) AS bus_cnt_2
  FROM bus_flg_cnt_2
  GROUP BY common_id, seg_no
),
bus_cnt_table AS (
  SELECT bf.*, b_s.bus_cnt, b_s.bus_cnt_2
  FROM (
    SELECT *
    FROM `input_sample`
    WHERE pred_tpmode="car" OR pred_tpmode="bike"
  ) AS bf
  LEFT JOIN bus_flg_sum AS b_s
    ON b_s.common_id = bf.common_id
    AND b_s.seg_no = bf.seg_no
),
move_table AS (
  SELECT
    * EXCEPT(pred_tpmode, purpose_flg, bus_cnt, bus_cnt_2),
    CASE
      WHEN EXTRACT(HOUR FROM DATETIME(arrive_ptime, "Asia/Tokyo")) >= 5
           AND EXTRACT(HOUR FROM DATETIME(depart_time, "Asia/Tokyo")) <= 22
           AND ((bus_cnt_2 + bus_cnt) / cnt >= 0.75)
      THEN "bus"
      ELSE pred_tpmode
    END AS pred_tpmode,
    purpose_flg
  FROM bus_cnt_table
),
table_car_v2 AS (
  SELECT
    common_id, seg_no, is_uuid, os, arrive_ptime, depart_time, visiting_seconds,
    cnt, mesh, is_stay, raw_element.sdk_detect_ptime, raw_element.latitude_anonymous,
    raw_element.longitude_anonymous, raw_element.accuracy,
    needs_tokuminer_flg, pred_tpmode, purpose_flg
  FROM move_table AS st
  CROSS JOIN UNNEST(st.raw_array) AS raw_element
  WHERE (pred_tpmode = "car" OR pred_tpmode = "bike")
    AND raw_element.latitude_anonymous BETWEEN -90 AND 90
    AND raw_element.longitude_anonymous BETWEEN -180 AND 180
),
group_car_table AS (
  SELECT
    mv.*,
    mv2.common_id AS nearby_id
  FROM table_car_v2 AS mv
  LEFT JOIN table_car_v2 AS mv2
    ON convert_to_mesh_9(mv.latitude_anonymous, mv.longitude_anonymous)
       = convert_to_mesh_9(mv2.latitude_anonymous, mv2.longitude_anonymous)
    AND DATE(mv.sdk_detect_ptime, "Asia/Tokyo")
        = DATE(mv2.sdk_detect_ptime, "Asia/Tokyo")
    AND TIMESTAMP_DIFF(mv.sdk_detect_ptime, mv2.sdk_detect_ptime, SECOND)
        BETWEEN -29 AND 30
    AND ST_DWithin(
      ST_GeogPoint(mv.longitude_anonymous, mv.latitude_anonymous),
      ST_GeogPoint(mv2.longitude_anonymous, mv2.latitude_anonymous),
      LEAST(mv.accuracy, 100)
    )
    AND mv.common_id != mv2.common_id
),
nearby_user_cnt AS (
  SELECT
    common_id,
    seg_no,
    nearby_id,
    COUNT(*) AS nearby_cnt
  FROM group_car_table
  GROUP BY common_id, seg_no, nearby_id
),
nearby_user_table AS (
  SELECT
    common_id,
    seg_no,
    COUNT(DISTINCT nearby_id) AS too_near_cnt
  FROM nearby_user_cnt
  WHERE nearby_cnt >= 2
  GROUP BY common_id, seg_no
  HAVING too_near_cnt >= 3
),
car_table_last AS (
  SELECT
    v2.* EXCEPT(pred_tpmode, purpose_flg),
    CASE WHEN nu.seg_no IS NOT NULL THEN 'bus' ELSE pred_tpmode END AS pred_tpmode,
    purpose_flg
  FROM move_table AS v2
  LEFT JOIN nearby_user_table AS nu
    ON v2.seg_no = nu.seg_no
    AND v2.common_id = nu.common_id
)
SELECT
  common_id, seg_no, is_uuid, os, latitude, longitude,
  arrive_ptime, depart_time, visiting_seconds, accuracy, cnt, mesh,
  is_stay, raw_array, needs_tokuminer_flg, pred_tpmode, purpose_flg
FROM car_table_last
UNION ALL
SELECT
  common_id, seg_no, is_uuid, os, latitude, longitude,
  arrive_ptime, depart_time, visiting_seconds, accuracy, cnt, mesh,
  is_stay, raw_array, needs_tokuminer_flg, pred_tpmode, purpose_flg
FROM table_not_car_bike;
