-- Manual Admin User Creation Script
-- Use this to create admin users directly in Supabase

-- STEP 1: First create the auth user in Supabase Dashboard
-- Go to Authentication → Users → Add User
-- Enter email and password
-- Copy the user ID that gets created

-- STEP 2: Then run this SQL, replacing the values:
INSERT INTO users (
  id, 
  email, 
  username, 
  display_name, 
  bio, 
  avatar_url, 
  color, 
  friend_code, 
  role
) VALUES (
  'PASTE_USER_ID_HERE'::uuid,  -- Replace with the UUID from auth.users
  'admin@example.com',           -- Replace with actual email
  'admin',                       -- Replace with desired username
  'Administrator',               -- Replace with display name
  'System Administrator',        -- Optional bio
  '',                           -- Optional avatar URL
  '#6366f1',                    -- Color
  upper(substring(md5(random()::text) from 1 for 6)), -- Auto-generated friend code
  'admin'                       -- Role: 'admin' or 'user'
);

-- Example for creating a regular user:
-- INSERT INTO users (id, email, username, display_name, bio, avatar_url, color, friend_code, role)
-- VALUES (
--   'USER_UUID_HERE'::uuid,
--   'user@example.com',
--   'johndoe',
--   'John Doe',
--   'Hello, I am John!',
--   'https://example.com/avatar.jpg',
--   '#4ECDC4',
--   upper(substring(md5(random()::text) from 1 for 6)),
--   'user'
-- );

-- Verify the user was created:
SELECT * FROM users WHERE email = 'admin@example.com';
