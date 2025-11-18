-- Add API key storage for users
-- This script adds columns to store encrypted API keys for Gemini and OpenAI

-- Add columns to users table for API keys
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS gemini_api_key TEXT DEFAULT NULL,
ADD COLUMN IF NOT EXISTS openai_api_key TEXT DEFAULT NULL;

-- Add a function to update API keys securely
CREATE OR REPLACE FUNCTION update_user_api_keys(
    user_id UUID,
    gemini_key TEXT DEFAULT NULL,
    openai_key TEXT DEFAULT NULL
)
RETURNS VOID AS $$
BEGIN
    -- Only allow users to update their own API keys
    IF user_id != auth.uid() THEN
        RAISE EXCEPTION 'Users can only update their own API keys';
    END IF;
    
    -- Update the API keys (they should be encrypted on the client side)
    UPDATE users 
    SET 
        gemini_api_key = gemini_key,
        openai_api_key = openai_key,
        updated_at = NOW()
    WHERE id = user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create a policy to allow users to update their own API keys
DROP POLICY IF EXISTS "Users can update own API keys" ON users;
CREATE POLICY "Users can update own API keys"
  ON users FOR UPDATE
  TO authenticated
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

-- Create a view for admin to see user API key status (without actual keys)
CREATE OR REPLACE VIEW admin_api_key_stats AS
SELECT
  id,
  email,
  username,
  display_name,
  CASE 
    WHEN gemini_api_key IS NOT NULL THEN 'Yes' 
    ELSE 'No' 
  END as has_gemini_key,
  CASE 
    WHEN openai_api_key IS NOT NULL THEN 'Yes' 
    ELSE 'No' 
  END as has_openai_key,
  created_at,
  updated_at
FROM users
ORDER BY created_at DESC;

-- Grant access to admin_stats view
GRANT SELECT ON admin_api_key_stats TO authenticated;

-- Success message
DO $$
BEGIN
    RAISE NOTICE '===========================================';
    RAISE NOTICE 'API Key Storage Added Successfully!';
    RAISE NOTICE '===========================================';
    RAISE NOTICE '✓ Added gemini_api_key column to users table';
    RAISE NOTICE '✓ Added openai_api_key column to users table';
    RAISE NOTICE '✓ Created update_user_api_keys function';
    RAISE NOTICE '✓ Added security policy for API key updates';
    RAISE NOTICE '✓ Created admin view for API key stats';
    RAISE NOTICE '';
    RAISE NOTICE 'Next steps:';
    RAISE NOTICE '1. Update frontend to include API key management';
    RAISE NOTICE '2. Implement client-side encryption for API keys';
    RAISE NOTICE '===========================================';
END $$;

SELECT 'API key storage setup complete! 🎉' as status;