-- ============================================
-- Quick Chat Database Updates
-- Major Features: Groups, Image Messages, Mobile Optimization
-- ============================================

-- ============================================
-- 1. GROUPS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS groups (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
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

-- Index for fast group code lookups
CREATE INDEX IF NOT EXISTS idx_groups_group_code ON groups(group_code);
CREATE INDEX IF NOT EXISTS idx_groups_created_by ON groups(created_by);

-- ============================================
-- 2. GROUP MEMBERS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS group_members (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    group_id UUID REFERENCES groups(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    role VARCHAR(20) DEFAULT 'member', -- 'admin', 'moderator', 'member'
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_read_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(group_id, user_id)
);

-- Indexes for fast queries
CREATE INDEX IF NOT EXISTS idx_group_members_group_id ON group_members(group_id);
CREATE INDEX IF NOT EXISTS idx_group_members_user_id ON group_members(user_id);
CREATE INDEX IF NOT EXISTS idx_group_members_role ON group_members(role);

-- ============================================
-- 3. UPDATE MESSAGES TABLE FOR GROUPS & IMAGES
-- ============================================

-- Add group support and image support to messages
ALTER TABLE messages 
ADD COLUMN IF NOT EXISTS group_id UUID REFERENCES groups(id) ON DELETE CASCADE,
ADD COLUMN IF NOT EXISTS message_type VARCHAR(20) DEFAULT 'text', -- 'text', 'image', 'file'
ADD COLUMN IF NOT EXISTS image_url TEXT,
ADD COLUMN IF NOT EXISTS image_width INTEGER,
ADD COLUMN IF NOT EXISTS image_height INTEGER,
ADD COLUMN IF NOT EXISTS file_url TEXT,
ADD COLUMN IF NOT EXISTS file_name TEXT,
ADD COLUMN IF NOT EXISTS file_size INTEGER,
ADD COLUMN IF NOT EXISTS reply_to UUID REFERENCES messages(id) ON DELETE SET NULL;

-- Make receiver_id nullable for group messages
ALTER TABLE messages 
ALTER COLUMN receiver_id DROP NOT NULL;

-- Add constraint: must have either receiver_id OR group_id
ALTER TABLE messages
ADD CONSTRAINT messages_receiver_or_group_check 
CHECK (
    (receiver_id IS NOT NULL AND group_id IS NULL) OR 
    (receiver_id IS NULL AND group_id IS NOT NULL)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_messages_group_id ON messages(group_id);
CREATE INDEX IF NOT EXISTS idx_messages_message_type ON messages(message_type);
CREATE INDEX IF NOT EXISTS idx_messages_reply_to ON messages(reply_to);

-- ============================================
-- 4. GROUP INVITES TABLE (Optional)
-- ============================================
CREATE TABLE IF NOT EXISTS group_invites (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    group_id UUID REFERENCES groups(id) ON DELETE CASCADE,
    invited_by UUID REFERENCES users(id) ON DELETE CASCADE,
    invited_user UUID REFERENCES users(id) ON DELETE CASCADE,
    status VARCHAR(20) DEFAULT 'pending', -- 'pending', 'accepted', 'declined'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    responded_at TIMESTAMP WITH TIME ZONE,
    UNIQUE(group_id, invited_user)
);

CREATE INDEX IF NOT EXISTS idx_group_invites_invited_user ON group_invites(invited_user);
CREATE INDEX IF NOT EXISTS idx_group_invites_status ON group_invites(status);

-- ============================================
-- 5. NOTIFICATIONS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    type VARCHAR(50) NOT NULL, -- 'friend_request', 'group_invite', 'mention', 'new_message'
    title VARCHAR(200) NOT NULL,
    message TEXT,
    link TEXT,
    read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_read ON notifications(read);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON notifications(created_at DESC);

-- ============================================
-- 6. UPDATE USERS TABLE FOR MOBILE
-- ============================================

-- Add mobile-specific preferences
ALTER TABLE users
ADD COLUMN IF NOT EXISTS push_notifications BOOLEAN DEFAULT TRUE,
ADD COLUMN IF NOT EXISTS notification_sound BOOLEAN DEFAULT TRUE,
ADD COLUMN IF NOT EXISTS compact_mode BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS theme VARCHAR(20) DEFAULT 'dark'; -- 'dark', 'light', 'auto'

-- ============================================
-- 7. MESSAGE REACTIONS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS message_reactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    message_id UUID REFERENCES messages(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    reaction VARCHAR(10) NOT NULL, -- emoji
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(message_id, user_id, reaction)
);

CREATE INDEX IF NOT EXISTS idx_message_reactions_message_id ON message_reactions(message_id);
CREATE INDEX IF NOT EXISTS idx_message_reactions_user_id ON message_reactions(user_id);

-- ============================================
-- 8. TYPING INDICATORS TABLE (Real-time)
-- ============================================
CREATE TABLE IF NOT EXISTS typing_indicators (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    chat_id UUID, -- can be user_id for DM or group_id for group
    chat_type VARCHAR(10) NOT NULL, -- 'dm' or 'group'
    is_typing BOOLEAN DEFAULT TRUE,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, chat_id, chat_type)
);

CREATE INDEX IF NOT EXISTS idx_typing_indicators_chat ON typing_indicators(chat_id, chat_type);

-- ============================================
-- 9. ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================

-- Enable RLS on new tables
ALTER TABLE groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE group_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE group_invites ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE message_reactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE typing_indicators ENABLE ROW LEVEL SECURITY;

-- Groups: Users can see groups they're members of
CREATE POLICY "Users can view their groups" ON groups
    FOR SELECT
    USING (
        id IN (
            SELECT group_id FROM group_members 
            WHERE user_id = auth.uid()
        )
    );

-- Groups: Only admins can update groups
CREATE POLICY "Admins can update groups" ON groups
    FOR UPDATE
    USING (
        id IN (
            SELECT group_id FROM group_members 
            WHERE user_id = auth.uid() AND role = 'admin'
        )
    );

-- Groups: Any authenticated user can create groups
CREATE POLICY "Users can create groups" ON groups
    FOR INSERT
    WITH CHECK (auth.uid() IS NOT NULL);

-- Group Members: Users can view members of their groups
CREATE POLICY "Users can view group members" ON group_members
    FOR SELECT
    USING (
        group_id IN (
            SELECT group_id FROM group_members 
            WHERE user_id = auth.uid()
        )
    );

-- Group Members: Admins can add/remove members
CREATE POLICY "Admins can manage members" ON group_members
    FOR ALL
    USING (
        group_id IN (
            SELECT group_id FROM group_members 
            WHERE user_id = auth.uid() AND role = 'admin'
        )
    );

-- Messages: Update policy for group messages
DROP POLICY IF EXISTS "Users can view their messages" ON messages;
CREATE POLICY "Users can view their messages" ON messages
    FOR SELECT
    USING (
        sender_id = auth.uid() OR 
        receiver_id = auth.uid() OR
        group_id IN (
            SELECT group_id FROM group_members 
            WHERE user_id = auth.uid()
        )
    );

-- Messages: Users can send to groups they're in
DROP POLICY IF EXISTS "Users can send messages" ON messages;
CREATE POLICY "Users can send messages" ON messages
    FOR INSERT
    WITH CHECK (
        sender_id = auth.uid() AND (
            receiver_id IS NOT NULL OR
            group_id IN (
                SELECT group_id FROM group_members 
                WHERE user_id = auth.uid()
            )
        )
    );

-- Notifications: Users can only see their own
CREATE POLICY "Users can view their notifications" ON notifications
    FOR SELECT
    USING (user_id = auth.uid());

CREATE POLICY "Users can update their notifications" ON notifications
    FOR UPDATE
    USING (user_id = auth.uid());

-- Message Reactions: Anyone in the chat can react
CREATE POLICY "Users can view reactions" ON message_reactions
    FOR SELECT
    USING (
        message_id IN (
            SELECT id FROM messages 
            WHERE sender_id = auth.uid() OR 
                  receiver_id = auth.uid() OR
                  group_id IN (
                      SELECT group_id FROM group_members 
                      WHERE user_id = auth.uid()
                  )
        )
    );

CREATE POLICY "Users can add reactions" ON message_reactions
    FOR INSERT
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can remove their reactions" ON message_reactions
    FOR DELETE
    USING (user_id = auth.uid());

-- ============================================
-- 10. HELPER FUNCTIONS
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

-- Function to get unread message count
CREATE OR REPLACE FUNCTION get_unread_count(p_user_id UUID)
RETURNS TABLE(chat_id UUID, chat_type VARCHAR, unread_count BIGINT) AS $$
BEGIN
    RETURN QUERY
    -- DM unread count
    SELECT 
        sender_id as chat_id,
        'dm'::VARCHAR as chat_type,
        COUNT(*)::BIGINT as unread_count
    FROM messages
    WHERE receiver_id = p_user_id 
      AND read = FALSE
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
$$ LANGUAGE plpgsql;

-- Function to update group member last_read_at
CREATE OR REPLACE FUNCTION update_group_last_read(p_user_id UUID, p_group_id UUID)
RETURNS VOID AS $$
BEGIN
    UPDATE group_members
    SET last_read_at = NOW()
    WHERE user_id = p_user_id AND group_id = p_group_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 11. TRIGGERS
-- ============================================

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

CREATE TRIGGER trigger_set_group_code
    BEFORE INSERT ON groups
    FOR EACH ROW
    EXECUTE FUNCTION set_group_code();

-- Auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_groups_timestamp
    BEFORE UPDATE ON groups
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at();

-- ============================================
-- 12. SAMPLE DATA (Optional - for testing)
-- ============================================

-- Insert a test group (commented out - uncomment to use)
-- INSERT INTO groups (name, description, color, created_by)
-- VALUES ('Test Group', 'A test group for development', '#667eea', 'USER_UUID_HERE');

-- ============================================
-- 13. PERFORMANCE OPTIMIZATION
-- ============================================

-- Analyze tables for query optimization
ANALYZE groups;
ANALYZE group_members;
ANALYZE messages;
ANALYZE notifications;
ANALYZE message_reactions;

-- ============================================
-- 14. CLEANUP OLD DATA (Optional)
-- ============================================

-- Function to clean up old typing indicators (older than 10 seconds)
CREATE OR REPLACE FUNCTION cleanup_typing_indicators()
RETURNS VOID AS $$
BEGIN
    DELETE FROM typing_indicators
    WHERE updated_at < NOW() - INTERVAL '10 seconds';
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- MIGRATION COMPLETE
-- ============================================

-- Verify tables exist
DO $$
BEGIN
    RAISE NOTICE 'Checking tables...';
    
    IF EXISTS (SELECT FROM pg_tables WHERE tablename = 'groups') THEN
        RAISE NOTICE '✓ groups table created';
    END IF;
    
    IF EXISTS (SELECT FROM pg_tables WHERE tablename = 'group_members') THEN
        RAISE NOTICE '✓ group_members table created';
    END IF;
    
    IF EXISTS (SELECT FROM pg_tables WHERE tablename = 'notifications') THEN
        RAISE NOTICE '✓ notifications table created';
    END IF;
    
    IF EXISTS (SELECT FROM pg_tables WHERE tablename = 'message_reactions') THEN
        RAISE NOTICE '✓ message_reactions table created';
    END IF;
    
    RAISE NOTICE 'Database migration completed successfully!';
END $$;
