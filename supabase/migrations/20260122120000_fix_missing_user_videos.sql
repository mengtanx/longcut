-- Migration: Fix Missing user_videos Entries
-- Purpose: Create user_videos entries from video_generations for videos
--          where the original RPC call failed but the video generation was recorded.
--
-- Background: When insert_video_analysis_server fails (e.g., FK constraint on
-- profiles not yet created), the user_videos entry is never created. However,
-- video_generations records still exist from credit consumption. This migration
-- creates the missing user_videos entries based on video_generations.
--
-- Note: This migration was already applied to production on 2026-01-22.
-- The v2 version adds a JOIN on profiles to avoid FK constraint violations
-- for orphaned video_generations records where the user no longer exists.

-- Create missing user_videos entries from video_generations
-- This links videos to users who generated them but don't have user_videos entries
INSERT INTO user_videos (user_id, video_id, accessed_at)
SELECT DISTINCT
  vg.user_id,
  va.id as video_id,
  vg.created_at as accessed_at
FROM video_generations vg
JOIN video_analyses va ON va.youtube_id = vg.youtube_id
JOIN profiles p ON p.id = vg.user_id  -- Ensure user exists in profiles
LEFT JOIN user_videos uv ON uv.user_id = vg.user_id AND uv.video_id = va.id
WHERE
  -- Only process records with valid user IDs
  vg.user_id IS NOT NULL
  -- Only if the video analysis exists
  AND va.id IS NOT NULL
  -- Only if user_videos entry doesn't exist yet
  AND uv.id IS NULL
ON CONFLICT (user_id, video_id) DO NOTHING;
