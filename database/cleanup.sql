-- ============================================
-- Quick Chat - Complete Database Cleanup
-- Run this FIRST to completely reset your database
-- Then run complete-setup.sql to rebuild everything
-- ============================================

-- ============================================
-- STEP 1: DROP ALL TRIGGERS FIRST
-- ============================================

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP TRIGGER IF EXISTS trigger_set_group_code ON groups;
DROP TRIGGER IF EXISTS trigger_update_groups_timestamp ON groups;

-- ============================================
-- STEP 2: DROP ALL FUNCTIONS
-- ============================================

DROP FUNCTION IF EXISTS handle_new_user();
DROP FUNCTION IF EXISTS are_friends(UUID, UUID);
DROP FUNCTION IF EXISTS is_admin();
DROP FUNCTION IF EXISTS generate_group_code();
DROP FUNCTION IF EXISTS set_group_code();
DROP FUNCTION IF EXISTS get_unread_count(UUID);
DROP FUNCTION IF EXISTS update_group_last_read(UUID, UUID);
DROP FUNCTION IF EXISTS cleanup_typing_indicators();

-- ============================================
-- STEP 3: DROP ALL VIEWS
-- ============================================

DROP VIEW IF EXISTS admin_stats;

-- ============================================
-- STEP 4: REMOVE TABLES FROM REALTIME PUBLICATION
-- ============================================

-- Safely remove all tables from realtime (ignore errors if tables don't exist)
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

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime DROP TABLE groups;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime DROP TABLE group_members;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime DROP TABLE group_invites;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime DROP TABLE notifications;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime DROP TABLE message_reactions;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime DROP TABLE typing_indicators;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- ============================================
-- STEP 5: DROP ALL TABLES (IN CORRECT ORDER)
-- ============================================

-- Drop tables with foreign keys first
DROP TABLE IF EXISTS message_reactions CASCADE;
DROP TABLE IF EXISTS notifications CASCADE;
DROP TABLE IF EXISTS group_invites CASCADE;
DROP TABLE IF EXISTS typing_indicators CASCADE;
DROP TABLE IF EXISTS messages CASCADE;
DROP TABLE IF EXISTS group_members CASCADE;
DROP TABLE IF EXISTS friendships CASCADE;
DROP TABLE IF EXISTS groups CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- ============================================
-- STEP 6: DROP ALL POLICIES (CLEANUP)
-- ============================================

-- This will be handled automatically when tables are dropped,
-- but we can explicitly drop them if they persist
DO $$
DECLARE
    policy_record RECORD;
BEGIN
    FOR policy_record IN
        SELECT schemaname, tablename, policyname
        FROM pg_policies
        WHERE schemaname = 'public'
        AND tablename IN ('users', 'friendships', 'groups', 'group_members', 'messages', 'notifications', 'message_reactions', 'typing_indicators', 'group_invites')
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I',
                      policy_record.policyname,
                      policy_record.schemaname,
                      policy_record.tablename);
    END LOOP;
END $$;

-- ============================================
-- STEP 7: DROP ALL INDEXES (OPTIONAL CLEANUP)
-- ============================================

DROP INDEX IF EXISTS idx_users_friend_code;
DROP INDEX IF EXISTS idx_users_role;
DROP INDEX IF EXISTS idx_friendships_user1;
DROP INDEX IF EXISTS idx_friendships_user2;
DROP INDEX IF EXISTS idx_messages_sender;
DROP INDEX IF EXISTS idx_messages_receiver;
DROP INDEX IF EXISTS idx_messages_group_id;
DROP INDEX IF EXISTS idx_messages_message_type;
DROP INDEX IF EXISTS idx_messages_created;
DROP INDEX IF EXISTS idx_groups_group_code;
DROP INDEX IF EXISTS idx_groups_created_by;
DROP INDEX IF EXISTS idx_group_members_group_id;
DROP INDEX IF EXISTS idx_group_members_user_id;
DROP INDEX IF EXISTS idx_group_members_role;
DROP INDEX IF EXISTS idx_group_invites_invited_user;
DROP INDEX IF EXISTS idx_group_invites_status;
DROP INDEX IF EXISTS idx_notifications_user_id;
DROP INDEX IF EXISTS idx_notifications_read;
DROP INDEX IF EXISTS idx_notifications_created_at;
DROP INDEX IF EXISTS idx_message_reactions_message_id;
DROP INDEX IF EXISTS idx_message_reactions_user_id;
DROP INDEX IF EXISTS idx_typing_indicators_chat;

-- ============================================
-- VERIFICATION & SUCCESS MESSAGE
-- ============================================

DO $$
DECLARE
    table_count INTEGER;
BEGIN
    -- Count remaining tables
    SELECT COUNT(*) INTO table_count
    FROM pg_tables
    WHERE schemaname = 'public'
    AND tablename IN ('users', 'friendships', 'groups', 'group_members', 'messages', 'notifications', 'message_reactions', 'typing_indicators', 'group_invites');

    RAISE NOTICE '===========================================';
    RAISE NOTICE '🧹 Quick Chat Database Cleanup Complete!';
    RAISE NOTICE '===========================================';

    IF table_count = 0 THEN
        RAISE NOTICE '✅ All Quick Chat tables removed successfully';
    ELSE
        RAISE NOTICE '⚠️  Warning: % tables still exist', table_count;
    END IF;

    RAISE NOTICE '';
    RAISE NOTICE 'Next steps:';
    RAISE NOTICE '1. Run complete-setup.sql to rebuild everything';
    RAISE NOTICE '2. Test your app - all features should work';
    RAISE NOTICE '';
    RAISE NOTICE '===========================================';
    RAISE NOTICE 'Database is now clean and ready for fresh setup! ✨';
    RAISE NOTICE '===========================================';
END $$;
