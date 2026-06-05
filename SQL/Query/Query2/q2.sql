-- Q2.  VERSION-OVER-VERSION IMPROVEMENT
--      For each model, compare consecutive version performance
--      to see whether retraining actually helped.
WITH ver_avg AS (
  SELECT
    tr.Model_ID,
    tr.Version_No,
    mv.Algorithm,
    ROUND(AVG(em.F1_Score)::numeric, 4)          AS avg_f1,
    ROUND(AVG(em.Accuracy)::numeric, 4)           AS avg_acc,
    ROUND(AVG(em.Validation_Loss)::numeric, 4)    AS avg_vloss,
    COUNT(DISTINCT tr.Run_ID)                     AS run_count
  FROM Training_Run tr
  JOIN Evaluation_Metric em ON em.Run_ID = tr.Run_ID
  JOIN Model_Version mv
    ON mv.Model_ID = tr.Model_ID
    AND mv.Version_No = tr.Version_No
  WHERE tr.Status = 'Completed'
  GROUP BY tr.Model_ID, tr.Version_No, mv.Algorithm
)
SELECT
  m.Model_Name,
  va.Version_No,
  va.Algorithm,
  va.avg_f1,
  va.avg_acc,
  va.avg_vloss,
  va.run_count,
  ROUND((va.avg_f1 - LAG(va.avg_f1) OVER (
    PARTITION BY va.Model_ID ORDER BY va.Version_No
  ))::numeric, 4) AS f1_delta_vs_prev,
  ROUND((va.avg_vloss - LAG(va.avg_vloss) OVER (
    PARTITION BY va.Model_ID ORDER BY va.Version_No
  ))::numeric, 4) AS loss_delta_vs_prev
FROM ver_avg va
JOIN Model m ON m.Model_ID = va.Model_ID
ORDER BY m.Model_Name, va.Version_No;
