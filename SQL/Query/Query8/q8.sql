-- Q8. TOP PERFORMERS PER PROBLEM TYPE
--      For each problem type (Classification, NLP, etc.)
--      find the single best model version using window rank.
WITH scored AS (
  SELECT
    m.Problem_Type,
    m.Model_Name,
    mv.Version_No,
    mv.Algorithm,
    ROUND(AVG(em.F1_Score)::numeric, 4)    AS avg_f1,
    ROUND(AVG(em.Accuracy)::numeric, 4)    AS avg_acc,
    ROUND(AVG(em.Validation_Loss)::numeric,4) AS avg_vloss,
    COUNT(DISTINCT tr.Run_ID)              AS run_count,
    RANK() OVER (
      PARTITION BY m.Problem_Type
      ORDER BY AVG(em.F1_Score) DESC
    ) AS type_rank
  FROM Evaluation_Metric em
  JOIN Training_Run tr ON tr.Run_ID = em.Run_ID
  JOIN Model_Version mv
    ON mv.Model_ID = tr.Model_ID
    AND mv.Version_No = tr.Version_No
  JOIN Model m ON m.Model_ID = mv.Model_ID
  WHERE tr.Status = 'Completed'
  GROUP BY m.Problem_Type, m.Model_Name, mv.Version_No, mv.Algorithm
)
SELECT
  Problem_Type,
  Model_Name,
  Version_No,
  Algorithm,
  avg_f1,
  avg_acc,
  avg_vloss,
  run_count
FROM scored
WHERE type_rank = 1
ORDER BY Problem_Type;
