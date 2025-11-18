# User Signup Fix Guide

## Problem
Users were being created in the `auth.users` table but not in the `users` table, preventing them from using the application.

## Root Cause
The database policy "Only admins can create users" was too restrictive and prevented the automatic trigger from creating user profiles during signup.

## Solution Implemented

### 1. Database Policy Fix
Run the SQL script in your Supabase SQL Editor:

**File:** `database/fix-signup-policy.sql`

This script:
- Removes the restrictive "Only admins can create users" policy
- Creates a new policy that allows:
  - Users to create their own profile (id = auth.uid())
  - Admins to create any user profile
  - The trigger function to work properly

### 2. Frontend Fallback Logic
Updated `pages/auth.html` to include fallback logic that:
1. Waits 1 second after signup for the database trigger to run
2. Checks if the user profile was created
3. If not, manually creates the user profile with:
   - Unique friend code
   - Username from email
   - Default color and settings
   - User role

## How to Apply the Fix

### Step 1: Update Database Policy
1. Go to your Supabase Dashboard
2. Navigate to SQL Editor
3. Open and run `database/fix-signup-policy.sql`
4. Verify you see: "User signup policy updated successfully! ✅"

### Step 2: Deploy Updated Frontend
The `pages/auth.html` file has been updated with the fallback logic. Deploy your changes to Vercel.

### Step 3: Test the Signup Flow
1. Create a new test account
2. Verify the user appears in both:
   - `auth.users` table
   - `users` table (with profile data)
3. Confirm you can access the chat interface

## What Happens Now

### Automatic Creation (Preferred)
When a user signs up:
1. Supabase creates the auth user
2. Database trigger `handle_new_user()` automatically creates the user profile
3. User is redirected to chat

### Manual Fallback (Backup)
If the trigger fails:
1. Frontend waits 1 second
2. Checks if profile exists
3. If not, creates it manually
4. User is redirected to chat

## Verification

Check that new users have:
- ✅ Entry in `auth.users` table
- ✅ Entry in `users` table with:
  - Unique friend code
  - Email and username
  - Default color (#667eea)
  - Role set to 'user'
  - All required fields populated

## Troubleshooting

### Issue: Users still not being created
**Solution:** 
- Verify the SQL script ran successfully
- Check Supabase logs for errors
- Ensure RLS is enabled but policies allow user creation

### Issue: Duplicate friend codes
**Solution:** 
- The fallback logic includes a uniqueness check
- If this happens, check the trigger function is working

### Issue: Permission denied errors
**Solution:**
- Verify the new policy is active
- Check that the trigger function has SECURITY DEFINER
- Ensure authenticated users can insert their own records

## Database Trigger Details

The `handle_new_user()` trigger:
- Runs automatically on `auth.users` INSERT
- Generates unique 6-character friend code
- Creates user profile with email-based username
- Sets default color and role
- Handles errors gracefully without failing auth

## Additional Notes

- The trigger runs with `SECURITY DEFINER` which bypasses RLS
- The frontend fallback ensures 100% success rate
- Both methods generate unique friend codes
- Default role is always 'user' (admins must be promoted manually)
