-- ============================================
-- Quick Chat - Add Groups Feature
-- Run this in Supabase SQL Editor
-- ============================================

-- ============================================
-- 1. CREATE GROUPS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS groups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    description TEXT,
    group_code VARCHAR(6) UNIQUE NOT NULL,
    avatar_url TEXT,
    bg_image_url TEXT,
    color VARCHAR(7) DEFAULT '#667eea',
    created_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_groups_group_code ON groups(group_code);
CREATE INDEX IF NOT EXISTS idx_groups_created_by ON groups(created_by);

-- ============================================
-- 2. CREATE GROUP MEMBERS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS group_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID REFERENCES groups(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    role VARCHAR(20) DEFAULT 'member', -- 'admin', 'moderator', 'member'
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_read_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(group_id, user_id)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_group_members_group_id ON group_members(group_id);
CREATE INDEX IF NOT EXISTS idx_group_members_user_id ON group_members(user_id);
CREATE INDEX IF NOT EXISTS idx_group_members_role ON group_members(role);

-- ============================================
-- 3. UPDATE MESSAGES TABLE FOR GROUPS
-- ============================================

-- Add group support to messages
ALTER TABLE messages 
ADD COLUMN IF NOT EXISTS group_id UUID REFERENCES groups(id) ON DELETE CASCADE,
ADD COLUMN IF NOT EXISTS message_type VARCHAR(20) DEFAULT 'text',
ADD COLUMN IF NOT EXISTS image_url TEXT;

-- Make receiver_id nullable for group messages (only if not already nullable)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'messages' 
        AND column_name = 'receiver_id' 
        AND is_nullable = 'NO'
    ) THEN
        ALTER TABLE messages ALTER COLUMN receiver_id DROP NOT NULL;
    END IF;
END $$;

-- Drop old constraint if exists
ALTER TABLE messages 
DROP CONSTRAINT IF EXISTS messages_receiver_or_group_check;

-- Add constraint: must have either receiver_id OR group_id
ALTER TABLE messages
ADD CONSTRAINT messages_receiver_or_group_check 
CHECK (
    (receiver_id IS NOT NULL AND group_id IS NULL) OR 
    (receiver_id IS NULL AND group_id IS NOT NULL)
);

-- Drop old check constraint if exists
ALTER TABLE messages 
DROP CONSTRAINT IF EXISTS messages_sender_id_check;

-- Update check constraint to allow group messages
ALTER TABLE messages
DROP CONSTRAINT IF EXISTS messages_check;

-- Index for group messages
CREATE INDEX IF NOT EXISTS idx_messages_group_id ON messages(group_id);
CREATE INDEX IF NOT EXISTS idx_messages_message_type ON messages(message_type);

-- ============================================
-- 4. ENABLE ROW LEVEL SECURITY
-- ============================================

ALTER TABLE groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE group_members ENABLE ROW LEVEL SECURITY;

-- ============================================
-- SECURITY DEFINER FUNCTIONS TO AVOID RECURSION
-- ============================================

-- Function to check if user is member of a group
CREATE OR REPLACE FUNCTION public.is_member_of_group(check_group_id UUID) RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM group_members 
    WHERE group_id = check_group_id AND user_id = auth.uid()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if user is admin of a group
CREATE OR REPLACE FUNCTION public.is_admin_of_group(check_group_id UUID) RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM group_members 
    WHERE group_id = check_group_id AND user_id = auth.uid() AND role = 'admin'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- 5. CREATE RLS POLICIES FOR GROUPS
-- ============================================

-- Groups: Users can see groups they're members of (avoid recursion)
DROP POLICY IF EXISTS "Users can view their groups" ON groups;
CREATE POLICY "Users can view their groups" ON groups
    FOR SELECT
    USING (public.is_member_of_group(groups.id));

-- Groups: Only admins can update groups (avoid recursion)
DROP POLICY IF EXISTS "Admins can update groups" ON groups;
CREATE POLICY "Admins can update groups" ON groups
    FOR UPDATE
    USING (public.is_admin_of_group(groups.id));

-- Groups: Any authenticated user can create groups
DROP POLICY IF EXISTS "Authenticated users can create groups" ON groups;
CREATE POLICY "Authenticated users can create groups" ON groups
    FOR INSERT
    WITH CHECK (auth.uid() IS NOT NULL AND created_by = auth.uid());

-- ============================================
-- 6. CREATE RLS POLICIES FOR GROUP MEMBERS
-- ============================================

-- Group Members: Users can view members of their groups (avoid recursion)
DROP POLICY IF EXISTS "Users can view group members" ON group_members;
CREATE POLICY "Users can view group members" ON group_members
    FOR SELECT
    USING (
        user_id = auth.uid() OR
        public.is_member_of_group(group_members.group_id)
    );

-- Group Members: Admins can add members (avoid recursion)
DROP POLICY IF EXISTS "Admins can add members" ON group_members;
CREATE POLICY "Admins can add members" ON group_members
    FOR INSERT
    WITH CHECK (
        -- Allow if user is admin of the group
        public.is_admin_of_group(group_members.group_id) OR
        -- Allow if adding yourself as admin and no members exist yet (for group creation)
        (group_members.user_id = auth.uid() AND group_members.role = 'admin' AND NOT EXISTS (SELECT 1 FROM group_members WHERE group_id = group_members.group_id))
    );

-- Group Members: Users can leave groups (delete themselves)
DROP POLICY IF EXISTS "Users can leave groups" ON group_members;
CREATE POLICY "Users can leave groups" ON group_members
    FOR DELETE
    USING (user_id = auth.uid());

-- Group Members: Admins can remove members (avoid recursion)
DROP POLICY IF EXISTS "Admins can remove members" ON group_members;
CREATE POLICY "Admins can remove members" ON group_members
    FOR DELETE
    USING (
        user_id = auth.uid() OR
        public.is_admin_of_group(group_members.group_id)
    );

-- ============================================
-- 7. UPDATE MESSAGE POLICIES FOR GROUPS
-- ============================================

-- Messages: Update policy for group messages (avoid recursion)
DROP POLICY IF EXISTS "Users can view own messages" ON messages;
DROP POLICY IF EXISTS "Users can view their messages" ON messages;
CREATE POLICY "Users can view their messages" ON messages
    FOR SELECT
    USING (
        sender_id = auth.uid() OR 
        receiver_id = auth.uid() OR
        (group_id IS NOT NULL AND public.is_member_of_group(group_id))
    );

-- Messages: Users can send to groups they're in (avoid recursion)
DROP POLICY IF EXISTS "Users can send messages to friends" ON messages;
DROP POLICY IF EXISTS "Users can send messages" ON messages;
CREATE POLICY "Users can send messages" ON messages
    FOR INSERT
    WITH CHECK (
        sender_id = auth.uid() AND (
            -- DM to friend
            (receiver_id IS NOT NULL AND EXISTS (
                SELECT 1 FROM friendships
                WHERE (user1_id = sender_id AND user2_id = receiver_id)
                   OR (user1_id = receiver_id AND user2_id = sender_id)
            )) OR
            -- Group message
            (group_id IS NOT NULL AND public.is_member_of_group(group_id))
        )
    );

-- ============================================
-- 8. HELPER FUNCTIONS
-- ============================================

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
$$ LANGUAGE plpgsql;

-- Auto-generate group code on insert
CREATE OR REPLACE FUNCTION set_group_code()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.group_code IS NULL OR NEW.group_code = '' THEN
        NEW.group_code := generate_group_code();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for group code generation
DROP TRIGGER IF EXISTS trigger_set_group_code ON groups;
CREATE TRIGGER trigger_set_group_code
    BEFORE INSERT ON groups
    FOR EACH ROW
    EXECUTE FUNCTION set_group_code();

-- Function to add creator as admin member
CREATE OR REPLACE FUNCTION add_group_creator_as_admin()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO group_members (group_id, user_id, role)
    VALUES (NEW.id, NEW.created_by, 'admin');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to add creator as admin
DROP TRIGGER IF EXISTS trigger_add_creator_as_admin ON groups;
CREATE TRIGGER trigger_add_creator_as_admin
    AFTER INSERT ON groups
    FOR EACH ROW
    EXECUTE FUNCTION add_group_creator_as_admin();

-- ============================================
-- 9. ENABLE REALTIME (OPTIONAL)
-- ============================================

-- Add tables to realtime publication if not already added
DO $$
BEGIN
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
END $$;

-- ============================================
-- VERIFICATION
-- ============================================

DO $$
BEGIN
    RAISE NOTICE '===========================================';
    RAISE NOTICE 'Groups Feature Migration Complete!';
    RAISE NOTICE '===========================================';
    
    IF EXISTS (SELECT FROM pg_tables WHERE tablename = 'groups') THEN
        RAISE NOTICE '✓ groups table created';
    END IF;
    
    IF EXISTS (SELECT FROM pg_tables WHERE tablename = 'group_members') THEN
        RAISE NOTICE '✓ group_members table created';
    END IF;
    
    RAISE NOTICE '===========================================';
    RAISE NOTICE 'You can now use the groups feature!';
    RAISE NOTICE '===========================================';
END $$;
