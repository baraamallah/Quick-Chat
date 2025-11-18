-- This script fixes the user signup process by creating a robust RLS policy
-- and ensuring the user creation trigger works as intended.

-- ============================================
-- STEP 1: DROP FLAWED POLICIES & TRIGGER
-- ============================================

-- Drop the broken "fix" policy if it exists
DROP POLICY IF EXISTS "Allow user creation on signup" ON users;

-- Drop the original restrictive policy if it exists
DROP POLICY IF EXISTS "Only admins can create users" ON users;

-- =tag:drop_trigger
-- Drop the existing trigger to recreate it with the right function
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
--end_tag

-- ============================================
-- STEP 2: RECREATE THE USER CREATION FUNCTION
-- ============================================

-- This function runs after a new user is created in `auth.users`
-- It creates a corresponding profile in the `public.users` table.
-- SECURITY INVOKER is crucial: It runs with the permissions of the user
-- who triggered it (the new user), not the function's owner.
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  new_friend_code TEXT;
BEGIN
  -- Generate a unique 6-character friend code
  LOOP
    new_friend_code := upper(substring(md5(random()::text) for 6));
    EXIT WHEN NOT EXISTS (SELECT 1 FROM public.users WHERE friend_code = new_friend_code);
  END LOOP;
  
  -- Insert the new user's profile.
  -- This will be allowed by the RLS policy defined in the next step.
  INSERT INTO public.users (id, email, username, display_name, color, friend_code, role)
  VALUES (
    NEW.id,
    NEW.email,
    split_part(NEW.email, '@', 1), -- Default username from email
    split_part(NEW.email, '@', 1), -- Default display name from email
    '#667eea',                     -- Default color
    new_friend_code,
    'user'                         -- Default role
  );
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER;

-- ============================================
-- STEP 3: RECREATE THE RLS INSERT POLICY
-- ============================================

-- This policy allows a newly authenticated user to create their OWN profile
-- in the `public.users` table. `auth.uid()` refers to the ID of the user
-- performing the action. The `handle_new_user` function, running as that user,
-- can therefore successfully insert the profile.
CREATE POLICY "Users can create their own profile"
  ON users FOR INSERT
  TO authenticated
  WITH CHECK (id = auth.uid());

-- ============================================
-- STEP 4: RECREATE THE TRIGGER
-- ============================================

-- This trigger calls the `handle_new_user` function after a new user signs up.
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- ============================================
-- SUCCESS MESSAGE
-- ============================================
SELECT 'User signup trigger and policy fixed successfully! ✅' as status;
