-- Manual Admin User Creation Script
-- Use this to create admin users directly in Supabase

-- STEP 1: First create the auth user in Supabase Dashboard
-- Go to Authentication → Users → Add User
-- Enter email and password
-- Copy the user ID that gets created

-- STEP 2: Then run this SQL with your user details:
INSERT INTO users (
  id, 
  email, 
  username, 
  display_name, 
  bio, 
  avatar_url,
  bg_image_url,
  color, 
  friend_code, 
  role
) VALUES (
  'b2256482-3464-459f-bf83-7fb65fd2c4ef'::uuid,
  'baraa.elmallah@gmail.com',
  'baraa',
  'Baraa',
  'System Administrator',
  '',
  '',
  '#6366f1',
  upper(substring(md5(random()::text) from 1 for 6)),
  'admin'
);

-- Verify the user was created:
SELECT * FROM users WHERE email = 'baraa.elmallah@gmail.com';

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
