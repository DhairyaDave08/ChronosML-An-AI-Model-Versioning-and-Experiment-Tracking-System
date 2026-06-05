-- Q1.  MODEL LEADERBOARD
--      Rank every model by its best-ever F1 score across all
--      versions and runs. Shows champion algorithm per model.


WITH best_run AS (
  SELECT
    tr.Model_ID,
    mv.Version_No,
    mv.Algorithm,
    em.Run_ID,
    em.F1_Score,
    em.Accuracy,
    em.Precision_Score,
    em.Recall,
    RANK() OVER (
      PARTITION BY tr.Model_ID
      ORDER BY em.F1_Score DESC
    ) AS rnk
  FROM Evaluation_Metric em
  JOIN Training_Run tr ON tr.Run_ID = em.Run_ID
  JOIN Model_Version mv
    ON mv.Model_ID = tr.Model_ID
    AND mv.Version_No = tr.Version_No
  WHERE tr.Status = 'Completed'
)
SELECT
  m.Model_Name,
  m.Category,
  m.Problem_Type,
  br.Version_No         AS best_version,
  br.Algorithm          AS best_algorithm,
  br.F1_Score           AS best_f1,
  br.Accuracy           AS best_accuracy,
  br.Precision_Score    AS best_precision,
  br.Recall             AS best_recall,
  RANK() OVER (ORDER BY br.F1_Score DESC) AS global_rank
FROM best_run br
JOIN Model m ON m.Model_ID = br.Model_ID
WHERE br.rnk = 1
ORDER BY global_rank;
 
