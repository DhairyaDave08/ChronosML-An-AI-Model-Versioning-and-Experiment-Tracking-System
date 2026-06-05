-- Q7.  ALGORITHM CATEGORY BENCHMARKS
--      Average metrics grouped by ML Category (Supervised,
--      Deep Learning, etc.) — high-level portfolio health.
SELECT
  m.Category,
  m.Problem_Type,
  COUNT(DISTINCT tr.Run_ID)                         AS total_runs,
  COUNT(DISTINCT m.Model_ID)                        AS model_count,
  ROUND(AVG(em.Accuracy)::numeric, 4)               AS avg_accuracy,
  ROUND(AVG(em.F1_Score)::numeric, 4)               AS avg_f1,
  ROUND(AVG(em.Validation_Loss)::numeric, 4)        AS avg_vloss,
  ROUND(STDDEV(em.F1_Score)::numeric, 4)            AS f1_std_dev,
  ROUND(MIN(em.F1_Score)::numeric, 4)               AS min_f1,
  ROUND(MAX(em.F1_Score)::numeric, 4)               AS max_f1,
  ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP
    (ORDER BY em.F1_Score)::numeric, 4)             AS median_f1
FROM Training_Run tr
JOIN Evaluation_Metric em ON em.Run_ID = tr.Run_ID
JOIN Model_Version mv
  ON mv.Model_ID = tr.Model_ID
  AND mv.Version_No = tr.Version_No
JOIN Model m ON m.Model_ID = tr.Model_ID
WHERE tr.Status = 'Completed'
GROUP BY m.Category, m.Problem_Type
ORDER BY avg_f1 DESC;
