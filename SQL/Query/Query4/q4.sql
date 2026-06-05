-- Q5.  USER PRODUCTIVITY SCORECARD
--      For each user: runs triggered, models owned, datasets
--      contributed to, and total artifact storage uploaded.
SELECT
  u.First_Name || ' ' || COALESCE(u.Middle_Name || ' ', '') || u.Last_Name
                                          AS full_name,
  u.Role,
  u.Email,
  COUNT(DISTINCT tr.Run_ID)              AS runs_triggered,
  COUNT(DISTINCT mc.Model_ID)
    FILTER (WHERE mc.Access_Level = 'Owner')
                                          AS models_owned,
  COUNT(DISTINCT r.Dataset_ID)           AS datasets_contributed,
  COUNT(DISTINCT ma.Artifact_ID)         AS artifacts_uploaded,
  ROUND(
    COALESCE(SUM(ma.File_Size),0) / 1073741824.0, 3
  )                                       AS total_storage_gb,
  COUNT(DISTINCT dep.Deployment_ID)      AS deployments_involved
FROM Users u
LEFT JOIN Training_Run tr  ON tr.User_ID = u.User_ID
LEFT JOIN Model_Created mc ON mc.User_ID = u.User_ID
LEFT JOIN Registers r      ON r.User_ID  = u.User_ID
LEFT JOIN Model_Artifact ma ON ma.User_ID = u.User_ID
LEFT JOIN Deploys dl        ON dl.User_ID = u.User_ID
LEFT JOIN Deployment dep    ON dep.Deployment_ID = dl.Deployment_ID
GROUP BY u.User_ID, u.First_Name, u.Middle_Name, u.Last_Name, u.Role, u.Email
ORDER BY runs_triggered DESC;
