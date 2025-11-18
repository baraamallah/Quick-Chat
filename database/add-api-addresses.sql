-- Add API address columns to users table
ALTER TABLE users
ADD COLUMN IF NOT EXISTS gemini_api_address TEXT,
ADD COLUMN IF NOT EXISTS openai_api_address TEXT;

-- Update the rpc function to save the addresses
CREATE OR REPLACE FUNCTION update_user_api_keys(
    user_id_in uuid,
    gemini_key_in text,
    openai_key_in text,
    gemini_address_in text,
    openai_address_in text
)
RETURNS void AS $$
BEGIN
    UPDATE users
    SET
        gemini_api_key = gemini_key_in,
        openai_api_key = openai_key_in,
        gemini_api_address = gemini_address_in,
        openai_api_address = openai_address_in
    WHERE id = user_id_in;
END;
$$ LANGUAGE plpgsql;

SELECT 'API address columns added and function updated successfully! ✅' as status;
