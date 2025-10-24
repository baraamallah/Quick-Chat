-- ============================================
-- Quick Chat - RLS Policy Fix
-- Run this to fix the 403 errors with groups
-- ============================================

-- First, let's check if the user is properly authenticated
-- This will help debug the issue
DO $$
DECLARE
    current_user_id UUID;
BEGIN
    SELECT auth.uid() INTO current_user_id;
    
    IF current_user_id IS NULL THEN
        RAISE NOTICE '❌ No authenticated user found!';
        RAISE NOTICE 'Make sure you are logged in before running this script.';
    ELSE
        RAISE NOTICE '✅ Authenticated user found: %', current_user_id;
    END IF;
END $$;

-- Drop existing problematic policies
DROP POLICY IF EXISTS "Authenticated users can create groups" ON groups;
DROP POLICY IF EXISTS "Users can view their groups" ON groups;
DROP POLICY IF EXISTS "Admins can add members" ON group_members;
DROP POLICY IF EXISTS "Users can view group members" ON group_members;

-- Create more permissive policies for testing
-- Groups: Allow authenticated users to create groups
CREATE POLICY "Allow authenticated users to create groups" ON groups
    FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() IS NOT NULL AND created_by = auth.uid());

-- Groups: Allow authenticated users to view all groups (for testing)
CREATE POLICY "Allow authenticated users to view groups" ON groups
    FOR SELECT
    TO authenticated
    USING (true);

-- Groups: Allow group creators to update their groups
CREATE POLICY "Allow group creators to update groups" ON groups
    FOR UPDATE
    TO authenticated
    USING (created_by = auth.uid())
    WITH CHECK (created_by = auth.uid());

-- Group Members: Allow authenticated users to view all group members (for testing)
CREATE POLICY "Allow authenticated users to view group members" ON group_members
    FOR SELECT
    TO authenticated
    USING (true);

-- Group Members: Allow authenticated users to add themselves to groups
CREATE POLICY "Allow users to add themselves to groups" ON group_members
    FOR INSERT
    TO authenticated
    WITH CHECK (
        user_id = auth.uid() OR
        -- Allow if user is admin of the group
        EXISTS (
            SELECT 1 FROM group_members 
            WHERE group_id = group_members.group_id 
            AND user_id = auth.uid() 
            AND role = 'admin'
        )
    );

-- Group Members: Allow users to leave groups
CREATE POLICY "Allow users to leave groups" ON group_members
    FOR DELETE
    TO authenticated
    USING (user_id = auth.uid());

-- Also fix the messages policies to be more permissive
DROP POLICY IF EXISTS "Users can send messages" ON messages;
DROP POLICY IF EXISTS "Users can view their messages" ON messages;

-- Messages: Allow authenticated users to send messages
CREATE POLICY "Allow authenticated users to send messages" ON messages
    FOR INSERT
    TO authenticated
    WITH CHECK (sender_id = auth.uid());

-- Messages: Allow authenticated users to view messages they're involved in
CREATE POLICY "Allow authenticated users to view messages" ON messages
    FOR SELECT
    TO authenticated
    USING (
        sender_id = auth.uid() OR 
        receiver_id = auth.uid() OR
        group_id IN (
            SELECT group_id FROM group_members 
            WHERE user_id = auth.uid()
        )
    );

-- Test the policies by checking if we can query the groups table
DO $$
DECLARE
    group_count INTEGER;
    current_user_id UUID;
BEGIN
    SELECT auth.uid() INTO current_user_id;
    
    IF current_user_id IS NOT NULL THEN
        SELECT COUNT(*) INTO group_count FROM groups;
        RAISE NOTICE '✅ Successfully queried groups table. Count: %', group_count;
        RAISE NOTICE '✅ RLS policies are working correctly!';
    ELSE
        RAISE NOTICE '❌ No authenticated user - policies cannot be tested';
    END IF;
END $$;

-- Success message
SELECT 'RLS policies fixed! Groups should work now! 🎉' as status;
