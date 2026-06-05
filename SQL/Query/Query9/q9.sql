-- Q9.  HYPERPARAMETER SENSITIVITY — LEARNING RATE vs F1
--      Extracts numeric learning_rate values and compares
--      them against final-snapshot F1 to spot sweet spots.
WITH final_snap AS (
  SELECT DISTINCT ON (Run_ID)
    Run_ID, F1_Score, Accuracy, Validation_Loss
  FROM Evaluation_Metric
  ORDER BY Run_ID, Snapshot_ID DESC
),
lr_vals AS (
  SELECT
    h.Run_ID,
    CAST(h.Value AS NUMERIC) AS learning_rate
  FROM Hyperparameter h
  WHERE h.Parameter_Name = 'learning_rate'
    AND h.Data_Type = 'float'
)
SELECT
  m.Model_Name,
  mv.Algorithm,
  ROUND(lr.learning_rate, 6)          AS learning_rate,
  ROUND(fs.F1_Score::numeric, 4)      AS final_f1,
  ROUND(fs.Accuracy::numeric, 4)      AS final_accuracy,
  ROUND(fs.Validation_Loss::numeric,4)AS final_vloss,
  CASE
    WHEN lr.learning_rate < 0.001  THEN 'very_low'
    WHEN lr.learning_rate < 0.01   THEN 'low'
    WHEN lr.learning_rate < 0.05   THEN 'medium'
    WHEN lr.learning_rate < 0.1    THEN 'high'
    ELSE                                'very_high'
  END AS lr_bucket
FROM lr_vals lr
JOIN final_snap fs ON fs.Run_ID = lr.Run_ID
JOIN Training_Run tr ON tr.Run_ID = lr.Run_ID
JOIN Model_Version mv
  ON mv.Model_ID = tr.Model_ID
  AND mv.Version_No = tr.Version_No
JOIN Model m ON m.Model_ID = tr.Model_ID
WHERE tr.Status = 'Completed'
ORDER BY lr.learning_rate;
