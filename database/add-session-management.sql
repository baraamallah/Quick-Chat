-- Add session management for one-time login per session
-- This script creates a table to track user sessions

-- Create sessions table
CREATE TABLE IF NOT EXISTS user_sessions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  session_token TEXT UNIQUE NOT NULL,
  device_info TEXT,
  ip_address TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  expires_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() + INTERVAL '24 hours'),
  is_active BOOLEAN DEFAULT true
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_user_sessions_user_id ON user_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_user_sessions_token ON user_sessions(session_token);
CREATE INDEX IF NOT EXISTS idx_user_sessions_expires ON user_sessions(expires_at);
CREATE INDEX IF NOT EXISTS idx_user_sessions_active ON user_sessions(is_active);

-- Enable RLS on sessions table
ALTER TABLE user_sessions ENABLE ROW LEVEL SECURITY;

-- Create policies for sessions
-- Users can view their own sessions
DROP POLICY IF EXISTS "Users can view own sessions" ON user_sessions;
CREATE POLICY "Users can view own sessions"
  ON user_sessions FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

-- Users can create their own sessions
DROP POLICY IF EXISTS "Users can create own sessions" ON user_sessions;
CREATE POLICY "Users can create own sessions"
  ON user_sessions FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

-- Users can update their own sessions
DROP POLICY IF EXISTS "Users can update own sessions" ON user_sessions;
CREATE POLICY "Users can update own sessions"
  ON user_sessions FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Users can delete their own sessions
DROP POLICY IF EXISTS "Users can delete own sessions" ON user_sessions;
CREATE POLICY "Users can delete own sessions"
  ON user_sessions FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());

-- Admins can manage all sessions
DROP POLICY IF EXISTS "Admins can manage all sessions" ON user_sessions;
CREATE POLICY "Admins can manage all sessions"
  ON user_sessions FOR ALL
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

-- Create function to create a new session
CREATE OR REPLACE FUNCTION create_user_session(
    p_user_id UUID,
    p_device_info TEXT DEFAULT NULL,
    p_ip_address TEXT DEFAULT NULL
)
RETURNS TEXT AS $$
DECLARE
    session_token TEXT;
BEGIN
    -- Only allow users to create sessions for themselves
    IF p_user_id != auth.uid() THEN
        RAISE EXCEPTION 'Users can only create sessions for themselves';
    END IF;
    
    -- Generate a unique session token
    session_token := encode(gen_random_bytes(32), 'hex');
    
    -- Insert the new session
    INSERT INTO user_sessions (user_id, session_token, device_info, ip_address)
    VALUES (p_user_id, session_token, p_device_info, p_ip_address);
    
    RETURN session_token;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to validate a session
CREATE OR REPLACE FUNCTION validate_user_session(p_session_token TEXT)
RETURNS BOOLEAN AS $$
DECLARE
    is_valid BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM user_sessions 
        WHERE session_token = p_session_token 
        AND is_active = true 
        AND expires_at > NOW()
    ) INTO is_valid;
    
    RETURN is_valid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to invalidate a session
CREATE OR REPLACE FUNCTION invalidate_user_session(p_session_token TEXT)
RETURNS VOID AS $$
BEGIN
    UPDATE user_sessions 
    SET is_active = false, expires_at = NOW()
    WHERE session_token = p_session_token;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to clean up expired sessions
CREATE OR REPLACE FUNCTION cleanup_expired_sessions()
RETURNS VOID AS $$
BEGIN
    DELETE FROM user_sessions 
    WHERE expires_at < NOW() OR is_active = false;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create a view for admin to see session stats
CREATE OR REPLACE VIEW admin_session_stats AS
SELECT
  COUNT(*) as total_sessions,
  COUNT(CASE WHEN is_active = true THEN 1 END) as active_sessions,
  COUNT(CASE WHEN is_active = false THEN 1 END) as inactive_sessions,
  COUNT(CASE WHEN expires_at < NOW() THEN 1 END) as expired_sessions,
  MIN(created_at) as oldest_session,
  MAX(created_at) as newest_session
FROM user_sessions;

-- Grant access to admin views
GRANT SELECT ON admin_session_stats TO authenticated;

-- Success message
DO $$
BEGIN
    RAISE NOTICE '===========================================';
    RAISE NOTICE 'Session Management Added Successfully!';
    RAISE NOTICE '===========================================';
    RAISE NOTICE '✓ Created user_sessions table';
    RAISE NOTICE '✓ Added indexes for performance';
    RAISE NOTICE '✓ Enabled Row Level Security';
    RAISE NOTICE '✓ Created security policies';
    RAISE NOTICE '✓ Created session management functions';
    RAISE NOTICE '✓ Created admin view for session stats';
    RAISE NOTICE '';
    RAISE NOTICE 'Next steps:';
    RAISE NOTICE '1. Update frontend to use session management';
    RAISE NOTICE '2. Implement automatic session cleanup';
    RAISE NOTICE '===========================================';
END $$;

SELECT 'Session management setup complete! 🎉' as status;