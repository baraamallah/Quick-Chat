-- Quick Chat Database Cleanup
-- Run this FIRST to remove old tables before running setup.sql

-- ============================================
-- DROP EXISTING TABLES AND OBJECTS
-- ============================================

-- Drop triggers first
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- Drop functions
DROP FUNCTION IF EXISTS handle_new_user();
DROP FUNCTION IF EXISTS are_friends(UUID, UUID);
DROP FUNCTION IF EXISTS is_admin();

-- Drop views
DROP VIEW IF EXISTS admin_stats;

-- Remove tables from realtime publication (ignore errors if tables don't exist)
DO $$ 
BEGIN
  ALTER PUBLICATION supabase_realtime DROP TABLE messages;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

DO $$ 
BEGIN
  ALTER PUBLICATION supabase_realtime DROP TABLE friendships;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

DO $$ 
BEGIN
  ALTER PUBLICATION supabase_realtime DROP TABLE users;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- Drop tables (in correct order due to foreign keys)
DROP TABLE IF EXISTS messages CASCADE;
DROP TABLE IF EXISTS friendships CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- Success message
SELECT 'Cleanup complete! Now run setup.sql' as status;
