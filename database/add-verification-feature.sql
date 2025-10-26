-- ============================================
-- Quick Chat - Add User Verification Feature
-- Run this in Supabase SQL Editor
-- ============================================

-- ============================================
-- 1. ADD VERIFICATION COLUMN TO USERS TABLE
-- ============================================

ALTER TABLE users 
ADD COLUMN IF NOT EXISTS is_verified BOOLEAN DEFAULT false;

-- Add index for verified users
CREATE INDEX IF NOT EXISTS idx_users_verified ON users(is_verified);

-- ============================================
-- 2. DROP OLD POLICIES
-- ============================================

DROP POLICY IF EXISTS "Users can update own profile" ON users;
DROP POLICY IF EXISTS "Admins can update verification" ON users;
DROP POLICY IF EXISTS "Admins can update user verification" ON users;

-- ============================================
-- 3. CREATE SIMPLIFIED POLICIES
-- ============================================

-- Policy 1: Users can update their own profile, but NOT verification
-- This policy allows users to update their own profile fields
-- but we'll use a WITH CHECK to prevent verification changes
CREATE POLICY "Users can update own profile" ON users
    FOR UPDATE
    TO authenticated
    USING (
        id = auth.uid()
    )
    WITH CHECK (
        -- Users can only update their own profile
        id = auth.uid()
    );

-- Policy 2: Admins can update ANY user (including verification)
-- This is a separate policy that gives admins full access
CREATE POLICY "Admins can update any user" ON users
    FOR UPDATE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() AND role = 'admin'
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

-- ============================================
-- 4. TRIGGER TO PREVENT USERS FROM VERIFYING THEMSELVES
-- ============================================

CREATE OR REPLACE FUNCTION prevent_user_self_verification()
RETURNS TRIGGER AS $$
BEGIN
    -- Check if user is trying to change verification status
    IF OLD.is_verified IS DISTINCT FROM NEW.is_verified THEN
        -- Allow if the user being updated is themselves and changing their own verification
        -- (this is for initial admin setup or if auth context isn't available)
        IF NEW.id = auth.uid() THEN
            -- User is trying to verify themselves - only allow if they're an admin
            IF OLD.role = 'admin' THEN
                -- Admins can verify themselves (for initial setup)
                RETURN NEW;
            ELSE
                -- Regular users cannot verify themselves
                RAISE EXCEPTION 'Only admins can change verification status';
            END IF;
        ELSIF auth.uid() IS NULL THEN
            -- No auth context (batch updates from SQL editor)
            -- Allow if the user being updated is an admin
            IF OLD.role = 'admin' THEN
                RETURN NEW;
            ELSE
                RAISE EXCEPTION 'Only admins can have verification status changed without auth';
            END IF;
        ELSIF NOT EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() AND role = 'admin'
        ) THEN
            -- Current user is not an admin - prevent verification changes
            RAISE EXCEPTION 'Only admins can change verification status';
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create the trigger
DROP TRIGGER IF EXISTS trigger_prevent_self_verification ON users;
CREATE TRIGGER trigger_prevent_self_verification
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION prevent_user_self_verification();

-- ============================================
-- 5. VERIFY INITIAL ADMIN
-- ============================================

-- Automatically verify the first admin (oldest created_at)
UPDATE users
SET is_verified = true
WHERE role = 'admin' 
AND id = (SELECT id FROM users WHERE role = 'admin' ORDER BY created_at ASC LIMIT 1);

-- ============================================
-- VERIFICATION
-- ============================================

DO $$
BEGIN
    RAISE NOTICE '===========================================';
    RAISE NOTICE 'Verification Feature Added!';
    RAISE NOTICE '===========================================';
    RAISE NOTICE '✓ is_verified column added to users table';
    RAISE NOTICE '✓ RLS policies updated';
    RAISE NOTICE '✓ Trigger prevents users from verifying themselves';
    RAISE NOTICE '✓ Only admins can verify users';
    RAISE NOTICE '✓ Verification badge will appear in UI';
    RAISE NOTICE '===========================================';
END $$;

SELECT 'Verification feature added successfully! 🎉' as status,
       'Only admins can verify users' as note;

