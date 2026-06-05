-- Q3.  DATASET SIZE vs. MODEL PERFORMANCE CORRELATION
--      Checks whether bigger datasets (Num_Rows) tend to
--      produce higher F1 scores — a core ML hypothesis.
SELECT
  d.Dataset_Name,
  dv.Version_No          AS dataset_version,
  dv.Num_Rows,
  dv.Num_Features,
  du.Split_Type,
  m.Model_Name,
  mv.Algorithm,
  ROUND(AVG(em.F1_Score)::numeric, 4)       AS avg_f1,
  ROUND(AVG(em.Accuracy)::numeric, 4)       AS avg_accuracy,
  ROUND(AVG(em.Validation_Loss)::numeric,4) AS avg_vloss,
  COUNT(DISTINCT tr.Run_ID)                 AS runs_using_this_dataset
FROM Dataset_Used du
JOIN Dataset_Version dv
  ON dv.Dataset_ID = du.Dataset_ID
  AND dv.Version_No = du.Version_No
JOIN Dataset d ON d.Dataset_ID = dv.Dataset_ID
JOIN Training_Run tr ON tr.Run_ID = du.Run_ID
JOIN Model_Version mv
  ON mv.Model_ID = tr.Model_ID
  AND mv.Version_No = tr.Version_No
JOIN Model m ON m.Model_ID = tr.Model_ID
JOIN Evaluation_Metric em ON em.Run_ID = tr.Run_ID
WHERE tr.Status = 'Completed'
  AND du.Split_Type = 'Train'
GROUP BY d.Dataset_Name, dv.Version_No, dv.Num_Rows,
         dv.Num_Features, du.Split_Type, m.Model_Name, mv.Algorithm
ORDER BY dv.Num_Rows DESC;
