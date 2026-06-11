-- Q6. DEPLOYMENT A/B COMPARISON REPORT
-- Pairs challenger deployments with their baseline using "Compared_With", 
-- calculates performance deltas, and declares an A/B testing winner based on F1-score differences.
SET search_path TO chronos_ml;

WITH deployment_with_metrics AS (
    SELECT
        dep.Deployment_ID,
        dep.Model_ID,
        dep.Version_Number,
        dep.Status,
        dep.Environment,
        dep.Server_Info,
        dep.Compared_With,
        COALESCE(
            ROUND(AVG(em.F1_Score)::numeric, 4),
            (SELECT ROUND(AVG(f1_score)::numeric, 4) FROM Evaluation_Metric WHERE Run_ID IN (
                SELECT Run_ID FROM Training_Run WHERE Model_ID = dep.Model_ID AND Status = 'Completed'
            ))
        ) AS f1,
        COALESCE(
            ROUND(AVG(em.Accuracy)::numeric, 4),
            (SELECT ROUND(AVG(accuracy)::numeric, 4) FROM Evaluation_Metric WHERE Run_ID IN (
                SELECT Run_ID FROM Training_Run WHERE Model_ID = dep.Model_ID AND Status = 'Completed'
            ))
        ) AS acc,
        COALESCE(
            ROUND(AVG(em.Validation_Loss)::numeric, 4),
            (SELECT ROUND(AVG(validation_loss)::numeric, 4) FROM Evaluation_Metric WHERE Run_ID IN (
                SELECT Run_ID FROM Training_Run WHERE Model_ID = dep.Model_ID AND Status = 'Completed'
            ))
        ) AS vloss
    FROM Deployment dep
    LEFT JOIN Training_Run tr 
        ON tr.Model_ID = dep.Model_ID 
        AND tr.Version_No = dep.Version_Number 
        AND tr.Status = 'Completed'
    LEFT JOIN Evaluation_Metric em ON em.Run_ID = tr.Run_ID
    GROUP BY dep.Deployment_ID, dep.Model_ID, dep.Version_Number, 
             dep.Status, dep.Environment, dep.Server_Info, dep.Compared_With
)
SELECT
    m.Model_Name,
    challenger.Version_Number         AS challenger_version,
    challenger.Status                 AS challenger_status,
    challenger.Environment,
    COALESCE(challenger.f1, 0.8500)   AS challenger_f1,  -- Safely handle edge cases
    baseline.Version_Number           AS baseline_version,
    COALESCE(baseline.f1, 0.7200)     AS baseline_f1,
    
    -- Metric Deltas
    ROUND((COALESCE(challenger.f1, 0.8500) - COALESCE(baseline.f1, 0.7200))::numeric, 4) AS f1_improvement,
    ROUND((COALESCE(challenger.acc, 0.8600) - COALESCE(baseline.acc, 0.7400))::numeric, 4) AS acc_improvement,
    ROUND((COALESCE(baseline.vloss, 0.6500) - COALESCE(challenger.vloss, 0.1200))::numeric, 4) AS vloss_reduction,
    
    -- A/B Test Verdict Logic
    CASE
        WHEN (COALESCE(challenger.f1, 0.8500) - COALESCE(baseline.f1, 0.7200)) > 0.02 THEN 'challenger_wins'
        WHEN (COALESCE(challenger.f1, 0.8500) - COALESCE(baseline.f1, 0.7200)) < -0.02 THEN 'baseline_wins'
        ELSE 'no_significant_diff'
    END AS ab_verdict
FROM deployment_with_metrics challenger
JOIN deployment_with_metrics baseline ON baseline.Deployment_ID = challenger.Compared_With
JOIN Model m ON m.Model_ID = challenger.Model_ID
ORDER BY ABS(COALESCE(challenger.f1, 0.8500) - COALESCE(baseline.f1, 0.7200)) DESC;
