-- Q7. MONTHLY TRAINING ACTIVITY HEATMAP
--      Run counts and success rate by year-month — shows
--      team velocity and operational reliability over time.
SELECT
  TO_CHAR(tr.Start_Time, 'YYYY-MM')          AS year_month,
  COUNT(*)                                    AS total_runs,
  COUNT(*) FILTER (WHERE tr.Status = 'Completed')  AS completed,
  COUNT(*) FILTER (WHERE tr.Status = 'Failed')     AS failed,
  COUNT(*) FILTER (WHERE tr.Status = 'Cancelled')  AS cancelled,
  ROUND(
    COUNT(*) FILTER (WHERE tr.Status = 'Completed')::numeric
    / NULLIF(COUNT(*), 0) * 100, 1
  )                                           AS success_rate_pct,
  COUNT(DISTINCT tr.User_ID)                  AS active_users,
  COUNT(DISTINCT tr.Model_ID)                 AS models_trained
FROM Training_Run tr
GROUP BY TO_CHAR(tr.Start_Time, 'YYYY-MM')
ORDER BY year_month;
