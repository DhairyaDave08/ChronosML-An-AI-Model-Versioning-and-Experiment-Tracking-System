-- Q6.  DEPLOYMENT A/B COMPARISON REPORT
--      For each deployment that has a Compared_With link,
--      show the metric delta between the two runs side-by-side.
WITH dep_metrics AS (
  SELECT
    dep.Deployment_ID,
    dep.Model_ID,
    dep.Version_Number,
    dep.Status,
    dep.Environment,
    dep.Server_Info,
    dep.Compared_With,
    ROUND(AVG(em.F1_Score)::numeric, 4)       AS f1,
    ROUND(AVG(em.Accuracy)::numeric, 4)       AS acc,
    ROUND(AVG(em.Validation_Loss)::numeric,4) AS vloss
  FROM Deployment dep
  JOIN Training_Run tr
    ON tr.Model_ID = dep.Model_ID
    AND tr.Version_No = dep.Version_Number
    AND tr.Status = 'Completed'
  JOIN Evaluation_Metric em ON em.Run_ID = tr.Run_ID
  GROUP BY dep.Deployment_ID, dep.Model_ID, dep.Version_Number,
           dep.Status, dep.Environment, dep.Server_Info, dep.Compared_With
)
SELECT
  m.Model_Name,
  challenger.Version_Number         AS challenger_version,
  challenger.Status                 AS challenger_status,
  challenger.Environment,
  challenger.Server_Info,
  challenger.f1                     AS challenger_f1,
  baseline.Version_Number           AS baseline_version,
  baseline.f1                       AS baseline_f1,
  ROUND((challenger.f1 - baseline.f1)::numeric, 4)
                                    AS f1_improvement,
  ROUND((challenger.acc - baseline.acc)::numeric, 4)
                                    AS acc_improvement,
  ROUND((baseline.vloss - challenger.vloss)::numeric, 4)
                                    AS vloss_reduction,
  CASE
    WHEN (challenger.f1 - baseline.f1) > 0.02 THEN 'challenger_wins'
    WHEN (challenger.f1 - baseline.f1) < -0.02 THEN 'baseline_wins'
    ELSE 'no_significant_diff'
  END                               AS ab_verdict
FROM dep_metrics challenger
JOIN dep_metrics baseline
  ON baseline.Deployment_ID = challenger.Compared_With
JOIN Model m ON m.Model_ID = challenger.Model_ID
ORDER BY ABS(challenger.f1 - baseline.f1) DESC;
