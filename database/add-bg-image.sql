-- Migration: Add bg_image_url column to users table
-- Run this if you already have the database set up

-- Add bg_image_url column
ALTER TABLE users ADD COLUMN IF NOT EXISTS bg_image_url TEXT DEFAULT '';

-- Success message
SELECT 'Background image column added successfully! 🎉' as status;
