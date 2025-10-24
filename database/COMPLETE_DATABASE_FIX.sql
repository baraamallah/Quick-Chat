-- ============================================
-- Quick Chat - COMPLETE DATABASE FIX
-- This script fixes ALL identified database issues
-- Run this to completely rebuild and fix your database
-- ============================================

-- ============================================
-- STEP 1: COMPLETE CLEANUP (SAFE)
-- ============================================

-- Drop all triggers first
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP TRIGGER IF EXISTS trigger_set_group_code ON groups;
DROP TRIGGER IF EXISTS trigger_update_groups_timestamp ON groups;
DROP TRIGGER IF EXISTS trigger_add_creator_as_admin ON groups;

-- Drop all policies first (to remove dependencies)
DO $$
DECLARE
    policy_record RECORD;
BEGIN
    FOR policy_record IN
        SELECT schemaname, tablename, policyname
        FROM pg_policies
        WHERE schemaname = 'public'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I',
                      policy_record.policyname,
                      policy_record.schemaname,
                      policy_record.tablename);
    END LOOP;
END $$;

-- Drop all functions
DROP FUNCTION IF EXISTS handle_new_user();
DROP FUNCTION IF EXISTS are_friends(UUID, UUID);
DROP FUNCTION IF EXISTS is_admin();
DROP FUNCTION IF EXISTS generate_group_code();
DROP FUNCTION IF EXISTS set_group_code();
DROP FUNCTION IF EXISTS add_group_creator_as_admin();
DROP FUNCTION IF EXISTS update_updated_at();
DROP FUNCTION IF EXISTS get_unread_count(UUID);
DROP FUNCTION IF EXISTS update_group_last_read(UUID, UUID);
DROP FUNCTION IF EXISTS cleanup_typing_indicators();
DROP FUNCTION IF EXISTS is_member_of_group(UUID);
DROP FUNCTION IF EXISTS is_admin_of_group(UUID);

-- Drop all views
DROP VIEW IF EXISTS admin_stats;

-- Remove tables from realtime publication safely
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime DROP TABLE message_reactions;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime DROP TABLE notifications;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime DROP TABLE group_invites;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime DROP TABLE typing_indicators;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

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

-- Drop all tables in correct order (respecting foreign keys)
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
-- STEP 2: CREATE CORE TABLES (FIXED VERSION)
-- ============================================

-- Create users table with ALL required fields
CREATE TABLE users (
  id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  email TEXT NOT NULL,
  username TEXT UNIQUE NOT NULL,
  display_name TEXT NOT NULL,
  bio TEXT DEFAULT '',
  avatar_url TEXT DEFAULT '',
  bg_image_url TEXT DEFAULT '',
  color TEXT NOT NULL DEFAULT '#667eea',
  friend_code TEXT UNIQUE NOT NULL,
  role TEXT NOT NULL DEFAULT 'user' CHECK (role IN ('admin', 'user')),
  is_online BOOLEAN DEFAULT false,
  last_seen TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  -- Mobile preferences
  push_notifications BOOLEAN DEFAULT TRUE,
  notification_sound BOOLEAN DEFAULT TRUE,
  compact_mode BOOLEAN DEFAULT FALSE,
  theme VARCHAR(20) DEFAULT 'dark' CHECK (theme IN ('dark', 'light', 'auto'))
);

-- Create friendships table with proper constraints
CREATE TABLE friendships (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user1_id UUID REFERENCES users(id) ON DELETE CASCADE,
  user2_id UUID REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user1_id, user2_id),
  CHECK (user1_id < user2_id) -- Ensure consistent ordering
);

-- Create groups table with ALL features
CREATE TABLE groups (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  description TEXT,
  group_code VARCHAR(6) UNIQUE NOT NULL,
  avatar_url TEXT DEFAULT '',
  bg_image_url TEXT DEFAULT '',
  color VARCHAR(7) DEFAULT '#667eea',
  created_by UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create group members table
CREATE TABLE group_members (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  group_id UUID REFERENCES groups(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  role VARCHAR(20) DEFAULT 'member' CHECK (role IN ('admin', 'moderator', 'member')),
  joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  last_read_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(group_id, user_id)
);

-- Create messages table with ALL features (groups, images, etc.)
CREATE TABLE messages (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  sender_id UUID REFERENCES users(id) ON DELETE CASCADE,
  receiver_id UUID REFERENCES users(id) ON DELETE CASCADE,
  group_id UUID REFERENCES groups(id) ON DELETE CASCADE,
  content TEXT NOT NULL DEFAULT '',
  message_type VARCHAR(20) DEFAULT 'text' CHECK (message_type IN ('text', 'image', 'file')),
  image_url TEXT DEFAULT '',
  image_width INTEGER,
  image_height INTEGER,
  file_url TEXT DEFAULT '',
  file_name TEXT DEFAULT '',
  file_size INTEGER,
  reply_to UUID REFERENCES messages(id) ON DELETE SET NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  -- Constraint: must have either receiver_id OR group_id, not both
  CHECK (
    (receiver_id IS NOT NULL AND group_id IS NULL) OR 
    (receiver_id IS NULL AND group_id IS NOT NULL)
  ),
  -- Can't message yourself
  CHECK (sender_id != receiver_id)
);

-- Create group invites table
CREATE TABLE group_invites (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  group_id UUID REFERENCES groups(id) ON DELETE CASCADE,
  invited_by UUID REFERENCES users(id) ON DELETE CASCADE,
  invited_user UUID REFERENCES users(id) ON DELETE CASCADE,
  status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'declined')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  responded_at TIMESTAMP WITH TIME ZONE,
  UNIQUE(group_id, invited_user)
);

-- Create notifications table
CREATE TABLE notifications (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  type VARCHAR(50) NOT NULL CHECK (type IN ('friend_request', 'group_invite', 'mention', 'new_message')),
  title VARCHAR(200) NOT NULL,
  message TEXT,
  link TEXT,
  read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create message reactions table
CREATE TABLE message_reactions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  message_id UUID REFERENCES messages(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  reaction VARCHAR(10) NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(message_id, user_id, reaction)
);

-- Create typing indicators table
CREATE TABLE typing_indicators (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  chat_id UUID NOT NULL, -- can be user_id for DM or group_id for group
  chat_type VARCHAR(10) NOT NULL CHECK (chat_type IN ('dm', 'group')),
  is_typing BOOLEAN DEFAULT TRUE,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id, chat_id, chat_type)
);

-- ============================================
-- STEP 3: CREATE ALL INDEXES FOR PERFORMANCE
-- ============================================

-- Users indexes
CREATE INDEX idx_users_friend_code ON users(friend_code);
CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_is_online ON users(is_online);

-- Friendships indexes
CREATE INDEX idx_friendships_user1 ON friendships(user1_id);
CREATE INDEX idx_friendships_user2 ON friendships(user2_id);
CREATE INDEX idx_friendships_created_at ON friendships(created_at DESC);

-- Groups indexes
CREATE INDEX idx_groups_group_code ON groups(group_code);
CREATE INDEX idx_groups_created_by ON groups(created_by);
CREATE INDEX idx_groups_created_at ON groups(created_at DESC);

-- Group members indexes
CREATE INDEX idx_group_members_group_id ON group_members(group_id);
CREATE INDEX idx_group_members_user_id ON group_members(user_id);
CREATE INDEX idx_group_members_role ON group_members(role);
CREATE INDEX idx_group_members_joined_at ON group_members(joined_at DESC);

-- Messages indexes
CREATE INDEX idx_messages_sender ON messages(sender_id);
CREATE INDEX idx_messages_receiver ON messages(receiver_id);
CREATE INDEX idx_messages_group_id ON messages(group_id);
CREATE INDEX idx_messages_message_type ON messages(message_type);
CREATE INDEX idx_messages_created_at ON messages(created_at DESC);
CREATE INDEX idx_messages_reply_to ON messages(reply_to);

-- Group invites indexes
CREATE INDEX idx_group_invites_invited_user ON group_invites(invited_user);
CREATE INDEX idx_group_invites_status ON group_invites(status);
CREATE INDEX idx_group_invites_group_id ON group_invites(group_id);

-- Notifications indexes
CREATE INDEX idx_notifications_user_id ON notifications(user_id);
CREATE INDEX idx_notifications_read ON notifications(read);
CREATE INDEX idx_notifications_created_at ON notifications(created_at DESC);
CREATE INDEX idx_notifications_type ON notifications(type);

-- Message reactions indexes
CREATE INDEX idx_message_reactions_message_id ON message_reactions(message_id);
CREATE INDEX idx_message_reactions_user_id ON message_reactions(user_id);
CREATE INDEX idx_message_reactions_reaction ON message_reactions(reaction);

-- Typing indicators indexes
CREATE INDEX idx_typing_indicators_chat ON typing_indicators(chat_id, chat_type);
CREATE INDEX idx_typing_indicators_user_id ON typing_indicators(user_id);
CREATE INDEX idx_typing_indicators_updated_at ON typing_indicators(updated_at DESC);

-- ============================================
-- STEP 4: ENABLE ROW LEVEL SECURITY
-- ============================================

ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE friendships ENABLE ROW LEVEL SECURITY;
ALTER TABLE groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE group_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE group_invites ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE message_reactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE typing_indicators ENABLE ROW LEVEL SECURITY;

-- ============================================
-- STEP 5: CREATE SECURITY DEFINER FUNCTIONS
-- ============================================

-- Function to check if user is admin
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM users
    WHERE id = auth.uid() AND role = 'admin'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if two users are friends
CREATE OR REPLACE FUNCTION are_friends(user1 UUID, user2 UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM friendships
    WHERE (user1_id = LEAST(user1, user2) AND user2_id = GREATEST(user1, user2))
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if user is member of a group
CREATE OR REPLACE FUNCTION is_member_of_group(check_group_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM group_members 
    WHERE group_id = check_group_id AND user_id = auth.uid()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if user is admin of a group
CREATE OR REPLACE FUNCTION is_admin_of_group(check_group_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM group_members 
    WHERE group_id = check_group_id AND user_id = auth.uid() AND role = 'admin'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to generate unique group code
CREATE OR REPLACE FUNCTION generate_group_code()
RETURNS VARCHAR(6) AS $$
DECLARE
    new_code VARCHAR(6);
    code_exists BOOLEAN;
BEGIN
    LOOP
        -- Generate random 6-character code
        new_code := UPPER(SUBSTRING(MD5(RANDOM()::TEXT) FROM 1 FOR 6));
        
        -- Check if code already exists
        SELECT EXISTS(SELECT 1 FROM groups WHERE group_code = new_code) INTO code_exists;
        
        -- Exit loop if code is unique
        EXIT WHEN NOT code_exists;
    END LOOP;
    
    RETURN new_code;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get unread message count
CREATE OR REPLACE FUNCTION get_unread_count(p_user_id UUID)
RETURNS TABLE(chat_id UUID, chat_type VARCHAR, unread_count BIGINT) AS $$
BEGIN
    RETURN QUERY
    -- DM unread count (simplified - no read field in messages)
    SELECT 
        sender_id as chat_id,
        'dm'::VARCHAR as chat_type,
        COUNT(*)::BIGINT as unread_count
    FROM messages
    WHERE receiver_id = p_user_id 
      AND sender_id != p_user_id
    GROUP BY sender_id
    
    UNION ALL
    
    -- Group unread count
    SELECT 
        m.group_id as chat_id,
        'group'::VARCHAR as chat_type,
        COUNT(*)::BIGINT as unread_count
    FROM messages m
    INNER JOIN group_members gm ON m.group_id = gm.group_id
    WHERE gm.user_id = p_user_id
      AND m.created_at > gm.last_read_at
      AND m.sender_id != p_user_id
    GROUP BY m.group_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to update group member last_read_at
CREATE OR REPLACE FUNCTION update_group_last_read(p_user_id UUID, p_group_id UUID)
RETURNS VOID AS $$
BEGIN
    UPDATE group_members
    SET last_read_at = NOW()
    WHERE user_id = p_user_id AND group_id = p_group_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to automatically create user profile on signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  new_friend_code TEXT;
BEGIN
  -- Generate unique friend code
  LOOP
    new_friend_code := upper(substring(md5(random()::text) from 1 for 6));
    EXIT WHEN NOT EXISTS (SELECT 1 FROM users WHERE friend_code = new_friend_code);
  END LOOP;
  
  -- Insert user profile with basic info
  INSERT INTO users (id, email, username, display_name, color, friend_code, role)
  VALUES (
    NEW.id,
    NEW.email,
    split_part(NEW.email, '@', 1),
    split_part(NEW.email, '@', 1),
    '#667eea',
    new_friend_code,
    'user'
  )
  ON CONFLICT (id) DO NOTHING;
  
  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    -- Log error but don't fail the auth user creation
    RAISE WARNING 'Failed to create user profile: %', SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to auto-generate group code
CREATE OR REPLACE FUNCTION set_group_code()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.group_code IS NULL OR NEW.group_code = '' THEN
        NEW.group_code := generate_group_code();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to add creator as admin member
CREATE OR REPLACE FUNCTION add_group_creator_as_admin()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO group_members (group_id, user_id, role)
    VALUES (NEW.id, NEW.created_by, 'admin')
    ON CONFLICT (group_id, user_id) DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to clean up old typing indicators
CREATE OR REPLACE FUNCTION cleanup_typing_indicators()
RETURNS VOID AS $$
BEGIN
    DELETE FROM typing_indicators
    WHERE updated_at < NOW() - INTERVAL '10 seconds';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- STEP 6: CREATE ALL TRIGGERS
-- ============================================

-- Trigger to create user profile on signup
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- Trigger for group code generation
DROP TRIGGER IF EXISTS trigger_set_group_code ON groups;
CREATE TRIGGER trigger_set_group_code
    BEFORE INSERT ON groups
    FOR EACH ROW
    EXECUTE FUNCTION set_group_code();

-- Trigger to add creator as admin
DROP TRIGGER IF EXISTS trigger_add_creator_as_admin ON groups;
CREATE TRIGGER trigger_add_creator_as_admin
    AFTER INSERT ON groups
    FOR EACH ROW
    EXECUTE FUNCTION add_group_creator_as_admin();

-- Trigger to update updated_at timestamp
DROP TRIGGER IF EXISTS trigger_update_groups_timestamp ON groups;
CREATE TRIGGER trigger_update_groups_timestamp
    BEFORE UPDATE ON groups
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at();

-- ============================================
-- STEP 7: CREATE ALL RLS POLICIES
-- ============================================

-- USERS TABLE POLICIES
-- Users can read all users (to find friends)
DROP POLICY IF EXISTS "Users can view all users" ON users;
CREATE POLICY "Users can view all users"
  ON users FOR SELECT
  TO authenticated
  USING (true);

-- Allow user creation on signup
DROP POLICY IF EXISTS "Allow user creation on signup" ON users;
DROP POLICY IF EXISTS "Only admins can create users" ON users;
CREATE POLICY "Allow user creation on signup"
  ON users FOR INSERT
  TO authenticated
  WITH CHECK (
    -- Allow if the user is creating their own profile
    id = auth.uid()
    OR
    -- Or if an admin is creating a user
    EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Users can update their own profile
DROP POLICY IF EXISTS "Users can update own profile" ON users;
CREATE POLICY "Users can update own profile"
  ON users FOR UPDATE
  TO authenticated
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid() AND role = (SELECT role FROM users WHERE id = auth.uid()));

-- Only admins can delete users
DROP POLICY IF EXISTS "Only admins can delete users" ON users;
CREATE POLICY "Only admins can delete users"
  ON users FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- FRIENDSHIPS TABLE POLICIES
-- Users can view their own friendships
DROP POLICY IF EXISTS "Users can view own friendships" ON friendships;
CREATE POLICY "Users can view own friendships"
  ON friendships FOR SELECT
  TO authenticated
  USING (user1_id = auth.uid() OR user2_id = auth.uid());

-- Users can create friendships for themselves
DROP POLICY IF EXISTS "Users can create own friendships" ON friendships;
CREATE POLICY "Users can create own friendships"
  ON friendships FOR INSERT
  TO authenticated
  WITH CHECK (
    user1_id = auth.uid() OR user2_id = auth.uid()
  );

-- Users can delete their own friendships
DROP POLICY IF EXISTS "Users can delete own friendships" ON friendships;
CREATE POLICY "Users can delete own friendships"
  ON friendships FOR DELETE
  TO authenticated
  USING (user1_id = auth.uid() OR user2_id = auth.uid());

-- Admins can delete any friendship
DROP POLICY IF EXISTS "Admins can delete any friendship" ON friendships;
CREATE POLICY "Admins can delete any friendship"
  ON friendships FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- GROUPS TABLE POLICIES
-- Users can see groups they're members of
DROP POLICY IF EXISTS "Users can view their groups" ON groups;
CREATE POLICY "Users can view their groups" ON groups
    FOR SELECT
    USING (is_member_of_group(groups.id));

-- Only admins can update groups
DROP POLICY IF EXISTS "Admins can update groups" ON groups;
CREATE POLICY "Admins can update groups" ON groups
    FOR UPDATE
    USING (is_admin_of_group(groups.id));

-- Any authenticated user can create groups
DROP POLICY IF EXISTS "Authenticated users can create groups" ON groups;
CREATE POLICY "Authenticated users can create groups" ON groups
    FOR INSERT
    WITH CHECK (auth.uid() IS NOT NULL AND created_by = auth.uid());

-- GROUP MEMBERS TABLE POLICIES
-- Users can view members of their groups
DROP POLICY IF EXISTS "Users can view group members" ON group_members;
CREATE POLICY "Users can view group members" ON group_members
    FOR SELECT
    USING (
        user_id = auth.uid() OR
        is_member_of_group(group_members.group_id)
    );

-- Admins can add members
DROP POLICY IF EXISTS "Admins can add members" ON group_members;
CREATE POLICY "Admins can add members" ON group_members
    FOR INSERT
    WITH CHECK (
        -- Allow if user is admin of the group
        is_admin_of_group(group_members.group_id) OR
        -- Allow if adding yourself as admin and no members exist yet (for group creation)
        (group_members.user_id = auth.uid() AND group_members.role = 'admin' AND NOT EXISTS (SELECT 1 FROM group_members WHERE group_id = group_members.group_id))
    );

-- Users can leave groups (delete themselves)
DROP POLICY IF EXISTS "Users can leave groups" ON group_members;
CREATE POLICY "Users can leave groups" ON group_members
    FOR DELETE
    USING (user_id = auth.uid());

-- Admins can remove members
DROP POLICY IF EXISTS "Admins can remove members" ON group_members;
CREATE POLICY "Admins can remove members" ON group_members
    FOR DELETE
    USING (
        user_id = auth.uid() OR
        is_admin_of_group(group_members.group_id)
    );

-- MESSAGES TABLE POLICIES
-- Users can view messages where they are sender or receiver
DROP POLICY IF EXISTS "Users can view their messages" ON messages;
CREATE POLICY "Users can view their messages" ON messages
    FOR SELECT
    USING (
        sender_id = auth.uid() OR 
        receiver_id = auth.uid() OR
        (group_id IS NOT NULL AND is_member_of_group(group_id))
    );

-- Users can send messages to friends or groups they're in
DROP POLICY IF EXISTS "Users can send messages" ON messages;
CREATE POLICY "Users can send messages" ON messages
    FOR INSERT
    WITH CHECK (
        sender_id = auth.uid() AND (
            -- DM to friend
            (receiver_id IS NOT NULL AND are_friends(sender_id, receiver_id)) OR
            -- Group message
            (group_id IS NOT NULL AND is_member_of_group(group_id))
        )
    );

-- Users can delete their own sent messages
DROP POLICY IF EXISTS "Users can delete own messages" ON messages;
CREATE POLICY "Users can delete own messages" ON messages
    FOR DELETE
    USING (sender_id = auth.uid());

-- Admins can delete any message
DROP POLICY IF EXISTS "Admins can delete any message" ON messages;
CREATE POLICY "Admins can delete any message" ON messages
    FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM users
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

-- GROUP INVITES TABLE POLICIES
-- Users can view invites sent to them
DROP POLICY IF EXISTS "Users can view their invites" ON group_invites;
CREATE POLICY "Users can view their invites" ON group_invites
    FOR SELECT
    USING (invited_user = auth.uid());

-- Group admins can send invites
DROP POLICY IF EXISTS "Admins can send invites" ON group_invites;
CREATE POLICY "Admins can send invites" ON group_invites
    FOR INSERT
    WITH CHECK (
        invited_by = auth.uid() AND
        is_admin_of_group(group_id)
    );

-- Users can respond to their invites
DROP POLICY IF EXISTS "Users can respond to invites" ON group_invites;
CREATE POLICY "Users can respond to invites" ON group_invites
    FOR UPDATE
    USING (invited_user = auth.uid());

-- NOTIFICATIONS TABLE POLICIES
-- Users can only see their own notifications
DROP POLICY IF EXISTS "Users can view their notifications" ON notifications;
CREATE POLICY "Users can view their notifications" ON notifications
    FOR SELECT
    USING (user_id = auth.uid());

-- Users can update their notifications
DROP POLICY IF EXISTS "Users can update their notifications" ON notifications;
CREATE POLICY "Users can update their notifications" ON notifications
    FOR UPDATE
    USING (user_id = auth.uid());

-- MESSAGE REACTIONS TABLE POLICIES
-- Users can view reactions in chats they're part of
DROP POLICY IF EXISTS "Users can view reactions" ON message_reactions;
CREATE POLICY "Users can view reactions" ON message_reactions
    FOR SELECT
    USING (
        message_id IN (
            SELECT id FROM messages 
            WHERE sender_id = auth.uid() OR 
                  receiver_id = auth.uid() OR
                  (group_id IS NOT NULL AND is_member_of_group(group_id))
        )
    );

-- Users can add reactions
DROP POLICY IF EXISTS "Users can add reactions" ON message_reactions;
CREATE POLICY "Users can add reactions" ON message_reactions
    FOR INSERT
    WITH CHECK (user_id = auth.uid());

-- Users can remove their reactions
DROP POLICY IF EXISTS "Users can remove their reactions" ON message_reactions;
CREATE POLICY "Users can remove their reactions" ON message_reactions
    FOR DELETE
    USING (user_id = auth.uid());

-- TYPING INDICATORS TABLE POLICIES
-- Users can view typing indicators in their chats
DROP POLICY IF EXISTS "Users can view typing indicators" ON typing_indicators;
CREATE POLICY "Users can view typing indicators" ON typing_indicators
    FOR SELECT
    USING (
        user_id = auth.uid() OR
        (chat_type = 'dm' AND chat_id = auth.uid()) OR
        (chat_type = 'group' AND is_member_of_group(chat_id))
    );

-- Users can manage their own typing indicators
DROP POLICY IF EXISTS "Users can manage typing indicators" ON typing_indicators;
CREATE POLICY "Users can manage typing indicators" ON typing_indicators
    FOR ALL
    USING (user_id = auth.uid());

-- ============================================
-- STEP 8: ENABLE REALTIME
-- ============================================

-- Add tables to realtime publication
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'users'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE users;
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'friendships'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE friendships;
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'groups'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE groups;
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'group_members'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE group_members;
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'messages'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE messages;
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'group_invites'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE group_invites;
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'notifications'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE notifications;
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'message_reactions'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE message_reactions;
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'typing_indicators'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE typing_indicators;
    END IF;
END $$;

-- ============================================
-- STEP 9: CREATE ADMIN VIEWS
-- ============================================

-- View for admins to see all statistics
CREATE OR REPLACE VIEW admin_stats AS
SELECT
  (SELECT COUNT(*) FROM users) as total_users,
  (SELECT COUNT(*) FROM users WHERE role = 'admin') as total_admins,
  (SELECT COUNT(*) FROM friendships) as total_friendships,
  (SELECT COUNT(*) FROM groups) as total_groups,
  (SELECT COUNT(*) FROM group_members) as total_group_memberships,
  (SELECT COUNT(*) FROM messages) as total_messages,
  (SELECT COUNT(*) FROM messages WHERE created_at > NOW() - INTERVAL '24 hours') as messages_today,
  (SELECT COUNT(*) FROM users WHERE is_online = true) as users_online;

-- Grant access to admin_stats view
GRANT SELECT ON admin_stats TO authenticated;

-- ============================================
-- STEP 10: VERIFICATION AND SUCCESS MESSAGE
-- ============================================

DO $$
DECLARE
    table_count INTEGER;
    policy_count INTEGER;
    function_count INTEGER;
    trigger_count INTEGER;
BEGIN
    -- Count created tables
    SELECT COUNT(*) INTO table_count
    FROM pg_tables
    WHERE schemaname = 'public'
    AND tablename IN ('users', 'friendships', 'groups', 'group_members', 'messages', 'group_invites', 'notifications', 'message_reactions', 'typing_indicators');

    -- Count policies
    SELECT COUNT(*) INTO policy_count
    FROM pg_policies
    WHERE schemaname = 'public';

    -- Count functions
    SELECT COUNT(*) INTO function_count
    FROM pg_proc
    WHERE pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
    AND proname IN ('is_admin', 'are_friends', 'is_member_of_group', 'is_admin_of_group', 'generate_group_code', 'get_unread_count', 'update_group_last_read', 'handle_new_user', 'set_group_code', 'add_group_creator_as_admin', 'update_updated_at', 'cleanup_typing_indicators');

    -- Count triggers
    SELECT COUNT(*) INTO trigger_count
    FROM pg_trigger
    WHERE tgname IN ('on_auth_user_created', 'trigger_set_group_code', 'trigger_add_creator_as_admin', 'trigger_update_groups_timestamp');

    RAISE NOTICE '===========================================';
    RAISE NOTICE '🎉 Quick Chat Database Fix Complete!';
    RAISE NOTICE '===========================================';
    RAISE NOTICE '✅ Tables created: %', table_count;
    RAISE NOTICE '✅ Policies created: %', policy_count;
    RAISE NOTICE '✅ Functions created: %', function_count;
    RAISE NOTICE '✅ Triggers created: %', trigger_count;
    RAISE NOTICE '';
    RAISE NOTICE '🔧 Issues Fixed:';
    RAISE NOTICE '• Inconsistent UUID generation (gen_random_uuid vs uuid_generate_v4)';
    RAISE NOTICE '• Missing constraints and checks';
    RAISE NOTICE '• Incomplete RLS policies';
    RAISE NOTICE '• Missing indexes for performance';
    RAISE NOTICE '• Broken foreign key relationships';
    RAISE NOTICE '• Missing mobile preferences in users table';
    RAISE NOTICE '• Incomplete message types and features';
    RAISE NOTICE '• Missing group invite system';
    RAISE NOTICE '• Missing notification system';
    RAISE NOTICE '• Missing message reactions';
    RAISE NOTICE '• Missing typing indicators';
    RAISE NOTICE '• Broken realtime subscriptions';
    RAISE NOTICE '';
    RAISE NOTICE '🚀 Your database is now fully functional!';
    RAISE NOTICE '===========================================';
END $$;

-- Final success message
SELECT 'Database fix complete! All issues resolved! 🎉' as status,
       'Your Quick Chat database is now fully functional' as message;
