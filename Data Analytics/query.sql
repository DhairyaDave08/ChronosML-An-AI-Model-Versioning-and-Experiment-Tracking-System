
SET search_path TO chronos_ml;
WITH
final_snap AS (
  SELECT DISTINCT ON (Run_ID)
    Run_ID,
    F1_Score,
    Accuracy,
    Precision_Score,
    Recall,
    Validation_Loss,
    Snapshot_ID         AS total_snapshots
  FROM Evaluation_Metric
  ORDER BY Run_ID, Snapshot_ID DESC
),
first_snap AS (
  SELECT DISTINCT ON (Run_ID)
    Run_ID,
    F1_Score            AS first_f1,
    Accuracy            AS first_accuracy,
    Validation_Loss     AS first_vloss
  FROM Evaluation_Metric
  ORDER BY Run_ID, Snapshot_ID ASC
),

hp_pivot AS (
  SELECT
    Run_ID,
    MAX(CASE WHEN Parameter_Name = 'learning_rate'     THEN Value END) AS learning_rate,
    MAX(CASE WHEN Parameter_Name = 'n_estimators'      THEN Value END) AS n_estimators,
    MAX(CASE WHEN Parameter_Name = 'max_depth'         THEN Value END) AS max_depth,
    MAX(CASE WHEN Parameter_Name = 'batch_size'        THEN Value END) AS batch_size,
    MAX(CASE WHEN Parameter_Name = 'epochs'            THEN Value END) AS epochs,
    MAX(CASE WHEN Parameter_Name = 'num_leaves'        THEN Value END) AS num_leaves,
    MAX(CASE WHEN Parameter_Name = 'subsample'         THEN Value END) AS subsample,
    MAX(CASE WHEN Parameter_Name = 'dropout'           THEN Value END) AS dropout,
    MAX(CASE WHEN Parameter_Name = 'weight_decay'      THEN Value END) AS weight_decay,
    MAX(CASE WHEN Parameter_Name = 'warmup_steps'      THEN Value END) AS warmup_steps,
    MAX(CASE WHEN Parameter_Name = 'n_clusters'        THEN Value END) AS n_clusters,
    MAX(CASE WHEN Parameter_Name = 'gamma'             THEN Value END) AS gamma,
    MAX(CASE WHEN Parameter_Name = 'clip_range'        THEN Value END) AS clip_range,
    MAX(CASE WHEN Parameter_Name = 'reg_lambda'        THEN Value END) AS reg_lambda,
    MAX(CASE WHEN Parameter_Name = 'colsample_bytree'  THEN Value END) AS colsample_bytree,
    COUNT(*)                                                            AS total_hyperparams
  FROM Hyperparameter
  GROUP BY Run_ID
),

dataset_info AS (
  SELECT
    du.Run_ID,
    SUM(dv.Num_Rows)             AS total_train_rows,
    MAX(dv.Num_Features)         AS max_features,
    AVG(dv.Num_Features)         AS avg_features,
    COUNT(DISTINCT du.Dataset_ID) AS dataset_count,
    STRING_AGG(DISTINCT d.Dataset_Name, ' | '
      ORDER BY d.Dataset_Name)   AS dataset_names,
    STRING_AGG(DISTINCT d.Status, ', '
      ORDER BY d.Status)         AS dataset_statuses,
    MAX(dv.Num_Rows)             AS largest_dataset_rows,
    MIN(dv.Num_Rows)             AS smallest_dataset_rows
  FROM Dataset_Used du
  JOIN Dataset_Version dv
    ON dv.Dataset_ID = du.Dataset_ID
    AND dv.Version_No = du.Version_No
  JOIN Dataset d ON d.Dataset_ID = du.Dataset_ID
  WHERE du.Split_Type = 'Train'
  GROUP BY du.Run_ID
),
deployment_flag AS (
  SELECT
    tr.Run_ID,
    COUNT(DISTINCT dep.Deployment_ID)                           AS deployment_count,
    MAX(CASE WHEN dep.Status = 'Production' THEN 1 ELSE 0 END) AS reached_production,
    MAX(CASE WHEN dep.Status = 'Retired'    THEN 1 ELSE 0 END) AS was_retired,
    MIN(dep.Deployed_At)                                        AS first_deployed_at
  FROM Training_Run tr
  LEFT JOIN Deployment dep
    ON dep.Model_ID    = tr.Model_ID
    AND dep.Version_Number = tr.Version_No
  GROUP BY tr.Run_ID
),
artifact_info AS (
  SELECT
    Run_ID,
    COUNT(*)                              AS artifact_count,
    SUM(File_Size)                        AS total_artifact_bytes,
    ROUND(SUM(File_Size) / 1073741824.0, 3) AS artifact_size_gb
  FROM Model_Artifact
  GROUP BY Run_ID
),
user_info AS (
  SELECT
    u.User_ID,
    u.Role                                AS user_role,
    COUNT(DISTINCT tr2.Run_ID)            AS user_total_runs,
    ROUND(
      COUNT(DISTINCT tr2.Run_ID) FILTER (WHERE tr2.Status = 'Completed')::numeric
      / NULLIF(COUNT(DISTINCT tr2.Run_ID), 0) * 100, 1
    )                                     AS user_success_rate_pct
  FROM Users u
  LEFT JOIN Training_Run tr2 ON tr2.User_ID = u.User_ID
  GROUP BY u.User_ID, u.Role
)
SELECT
  tr.Run_ID                                                     AS run_id,
  tr.Model_ID                                                   AS model_id,
  tr.Version_No                                                 AS version_no,

  m.Model_Name                                                  AS model_name,
  m.Category                                                    AS category,
  m.Problem_Type                                                AS problem_type,
  m.License_Type                                                AS license_type,
  m.Is_Public::INT                                              AS is_public,
  mv.Algorithm                                                  AS algorithm,
  mv.Status                                                     AS version_status,

  tr.Status                                                     AS run_status,
  CASE WHEN tr.Status = 'Completed' THEN 1 ELSE 0 END          AS run_success,
  tr.Start_Time                                                 AS start_time,
  tr.End_Time                                                   AS end_time,
  ROUND(
    EXTRACT(EPOCH FROM
      COALESCE(tr.End_Time, tr.Start_Time) - tr.Start_Time
    ) / 3600.0, 4
  )                                                             AS duration_hours,
  EXTRACT(HOUR   FROM tr.Start_Time)                           AS start_hour,
  EXTRACT(DOW    FROM tr.Start_Time)                           AS start_day_of_week,
  EXTRACT(MONTH  FROM tr.Start_Time)                           AS start_month,
  EXTRACT(YEAR   FROM tr.Start_Time)                           AS start_year,

  ui.user_role,
  ui.user_total_runs,
  ui.user_success_rate_pct,

  hp.learning_rate::NUMERIC                                     AS learning_rate,
  hp.n_estimators::NUMERIC                                      AS n_estimators,
  hp.max_depth::NUMERIC                                         AS max_depth,
  hp.batch_size::NUMERIC                                        AS batch_size,
  hp.epochs::NUMERIC                                            AS epochs,
  hp.num_leaves::NUMERIC                                        AS num_leaves,
  hp.subsample::NUMERIC                                         AS subsample,
  hp.dropout::NUMERIC                                           AS dropout,
  hp.weight_decay::NUMERIC                                      AS weight_decay,
  hp.warmup_steps::NUMERIC                                      AS warmup_steps,
  hp.n_clusters::NUMERIC                                        AS n_clusters,
  hp.gamma::NUMERIC                                             AS gamma,
  hp.clip_range::NUMERIC                                        AS clip_range,
  hp.reg_lambda::NUMERIC                                        AS reg_lambda,
  hp.colsample_bytree::NUMERIC                                  AS colsample_bytree,
  COALESCE(hp.total_hyperparams, 0)                             AS total_hyperparams,

  COALESCE(di.total_train_rows,     0)                          AS total_train_rows,
  COALESCE(di.max_features,         0)                          AS max_features,
  COALESCE(di.avg_features,         0)                          AS avg_features,
  COALESCE(di.dataset_count,        0)                          AS dataset_count,
  COALESCE(di.largest_dataset_rows, 0)                          AS largest_dataset_rows,
  COALESCE(di.smallest_dataset_rows,0)                          AS smallest_dataset_rows,
  di.dataset_names,
  di.dataset_statuses,

  ROUND(
    LN(GREATEST(di.total_train_rows, 1) + 1) * COALESCE(di.max_features, 0)
  , 4)                                                          AS dataset_complexity_score,

  fs.F1_Score                                                   AS final_f1,
  fs.Accuracy                                                   AS final_accuracy,
  fs.Precision_Score                                            AS final_precision,
  fs.Recall                                                     AS final_recall,
  fs.Validation_Loss                                            AS final_vloss,
  fs.total_snapshots,
  fst.first_f1,
  fst.first_accuracy,
  fst.first_vloss,
  ROUND((fs.F1_Score       - COALESCE(fst.first_f1,      fs.F1_Score))::NUMERIC,     4) AS f1_improvement,
  ROUND((fs.Accuracy       - COALESCE(fst.first_accuracy,fs.Accuracy))::NUMERIC,     4) AS accuracy_improvement,
  ROUND((COALESCE(fst.first_vloss, fs.Validation_Loss) - fs.Validation_Loss)::NUMERIC,4) AS vloss_reduction,

  CASE
    WHEN fs.F1_Score >= 0.90 THEN 'excellent'
    WHEN fs.F1_Score >= 0.80 THEN 'good'
    WHEN fs.F1_Score >= 0.70 THEN 'fair'
    WHEN fs.F1_Score IS NOT NULL THEN 'poor'
    ELSE 'no_eval'
  END                                                           AS f1_bucket,

  ROUND((fs.Precision_Score - fs.Recall)::NUMERIC, 4)          AS precision_recall_gap,
  CASE
    WHEN (fs.Precision_Score - fs.Recall) >  0.15 THEN 'high_precision_low_recall'
    WHEN (fs.Precision_Score - fs.Recall) < -0.15 THEN 'high_recall_low_precision'
    WHEN fs.F1_Score IS NOT NULL                   THEN 'balanced'
    ELSE 'no_eval'
  END                                                           AS imbalance_type,
  
  COALESCE(df.deployment_count,    0)                           AS deployment_count,
  COALESCE(df.reached_production,  0)                           AS reached_production,
  COALESCE(df.was_retired,         0)                           AS was_retired,
  df.first_deployed_at,

  COALESCE(ai.artifact_count,      0)                           AS artifact_count,
  COALESCE(ai.artifact_size_gb,    0)                           AS artifact_size_gb

FROM Training_Run tr
JOIN Model_Version mv
  ON  mv.Model_ID   = tr.Model_ID
  AND mv.Version_No = tr.Version_No
JOIN Model m
  ON  m.Model_ID    = tr.Model_ID
LEFT JOIN final_snap    fs  ON  fs.Run_ID  = tr.Run_ID
LEFT JOIN first_snap    fst ON fst.Run_ID  = tr.Run_ID
LEFT JOIN hp_pivot      hp  ON  hp.Run_ID  = tr.Run_ID
LEFT JOIN dataset_info  di  ON  di.Run_ID  = tr.Run_ID
LEFT JOIN deployment_flag df ON df.Run_ID  = tr.Run_ID
LEFT JOIN artifact_info ai  ON  ai.Run_ID  = tr.Run_ID
LEFT JOIN user_info     ui  ON  ui.User_ID = tr.User_ID
ORDER BY tr.Start_Time ASC

