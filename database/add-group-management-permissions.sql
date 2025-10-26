-- ============================================
-- Quick Chat - Add Group Management Permissions
-- Run this to enable group deletion and member removal
-- ============================================

-- Add policy for groups deletion (only group creator/admin can delete)
DROP POLICY IF EXISTS "Admins can delete groups" ON groups;
CREATE POLICY "Admins can delete groups" ON groups
    FOR DELETE
    TO authenticated
    USING (
        -- Allow if user is the creator
        created_by = auth.uid() OR
        -- Allow if user is an admin member
        EXISTS (
            SELECT 1 FROM group_members 
            WHERE group_id = groups.id 
            AND user_id = auth.uid() 
            AND role = 'admin'
        )
    );

-- Add policy for group members deletion by admins (to remove other members)
DROP POLICY IF EXISTS "Admins can remove other members from groups" ON group_members;
CREATE POLICY "Admins can remove other members from groups" ON group_members
    FOR DELETE
    TO authenticated
    USING (
        -- Allow if removing yourself
        user_id = auth.uid() OR
        -- Allow if you're an admin of the group
        EXISTS (
            SELECT 1 FROM group_members gm
            WHERE gm.group_id = group_members.group_id 
            AND gm.user_id = auth.uid() 
            AND gm.role = 'admin'
        )
    );

-- Verify policies
DO $$
DECLARE
    policy_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO policy_count 
    FROM pg_policies 
    WHERE tablename IN ('groups', 'group_members')
    AND policyname LIKE '%delete%' OR policyname LIKE '%remove%';
    
    RAISE NOTICE '===========================================';
    RAISE NOTICE 'Group Management Permissions Added!';
    RAISE NOTICE '===========================================';
    RAISE NOTICE '✓ Groups can now be deleted by admins';
    RAISE NOTICE '✓ Admins can remove other members';
    RAISE NOTICE '✓ Users can still leave groups themselves';
    RAISE NOTICE '===========================================';
END $$;

SELECT 'Group management permissions added! 🎉' as status;

