-- Q10. END-TO-END MODEL PIPELINE SUMMARY
--      One row per model showing the full lifecycle:
--      dataset source → training → evaluation → deployment.
--      The ultimate operational dashboard query.
WITH best_run AS (
  SELECT DISTINCT ON (tr.Model_ID)
    tr.Model_ID,
    tr.Run_ID,
    tr.Version_No,
    em.F1_Score,
    em.Accuracy,
    em.Validation_Loss
  FROM Training_Run tr
  JOIN Evaluation_Metric em
    ON em.Run_ID = tr.Run_ID
  WHERE tr.Status = 'Completed'
  ORDER BY tr.Model_ID, em.F1_Score DESC
),

latest_deploy AS (
  SELECT DISTINCT ON (Model_ID)
    Model_ID,
    Status AS deploy_status,
    Environment,
    Server_Info,
    Deployed_At
  FROM Deployment
  ORDER BY Model_ID, Deployed_At DESC
),

dataset_summary AS (
  SELECT
    tr.Model_ID,
    STRING_AGG(
      DISTINCT d.Dataset_Name,
      ' | ' ORDER BY d.Dataset_Name
    ) AS datasets_used
  FROM Training_Run tr
  JOIN Dataset_Used du
    ON du.Run_ID = tr.Run_ID
  JOIN Dataset d
    ON d.Dataset_ID = du.Dataset_ID
  WHERE tr.Status = 'Completed'
  GROUP BY tr.Model_ID
)

SELECT
  m.Model_Name,
  m.Category,
  m.Problem_Type,
  m.License_Type,
  m.Is_Public,

  br.Version_No AS best_version,
  mv.Algorithm AS best_algorithm,

  ROUND(br.F1_Score::numeric,4) AS best_f1,
  ROUND(br.Accuracy::numeric,4) AS best_accuracy,
  ROUND(br.Validation_Loss::numeric,4) AS best_vloss,

  ds.datasets_used,

  ld.deploy_status,
  ld.Environment AS deploy_env,
  ld.Server_Info AS deploy_server,
  ld.Deployed_At,

  CASE
    WHEN ld.deploy_status = 'Production'
         AND br.F1_Score >= 0.80
      THEN 'LIVE & HIGH PERFORMING'

    WHEN ld.deploy_status = 'Production'
      THEN 'LIVE - NEEDS ATTENTION'

    WHEN br.Run_ID IS NOT NULL
      THEN 'TRAINED - NOT DEPLOYED'

    ELSE 'NO COMPLETED RUNS'
  END AS lifecycle_status

FROM Model m

LEFT JOIN best_run br
  ON br.Model_ID = m.Model_ID

LEFT JOIN Model_Version mv
  ON mv.Model_ID = br.Model_ID
 AND mv.Version_No = br.Version_No

LEFT JOIN latest_deploy ld
  ON ld.Model_ID = m.Model_ID

LEFT JOIN dataset_summary ds
  ON ds.Model_ID = m.Model_ID

ORDER BY
  CASE
    WHEN ld.deploy_status = 'Production'
         AND br.F1_Score >= 0.80 THEN 1
    WHEN ld.deploy_status = 'Production' THEN 2
    WHEN br.Run_ID IS NOT NULL THEN 3
    ELSE 4
  END,
  br.F1_Score DESC NULLS LAST;
