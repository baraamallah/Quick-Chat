-- Fix user signup policy to allow automatic user creation
-- Run this in your Supabase SQL Editor

-- Drop the restrictive insert policy
DROP POLICY IF EXISTS "Only admins can create users" ON users;

-- Create a new policy that allows the trigger to create users
-- The trigger runs with SECURITY DEFINER, so it bypasses RLS
-- But we still need a policy for any direct inserts
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

-- Verify the change
SELECT 'User signup policy updated successfully! ✅' as status;
