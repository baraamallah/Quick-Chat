// Initialize Supabase client
let supabaseClient = null;

function initSupabase() {
    if (!validateConfig()) {
        showConfigError();
        throw new Error('Supabase configuration required');
    }
    
    supabaseClient = supabase.createClient(SUPABASE_CONFIG.url, SUPABASE_CONFIG.anonKey);
    return supabaseClient;
}

function showConfigError() {
    document.body.innerHTML = `
        <div style="display: flex; justify-content: center; align-items: center; height: 100vh; text-align: center; padding: 20px;">
            <div style="background: white; padding: 40px; border-radius: 20px; max-width: 500px; box-shadow: 0 20px 60px rgba(0,0,0,0.3);">
                <h1 style="color: #667eea; margin-bottom: 20px;">⚠️ Configuration Required</h1>
                <p style="color: #666; margin-bottom: 20px;">
                    Please configure your Supabase credentials in <code style="background: #f0f0f0; padding: 2px 8px; border-radius: 4px;">js/config.js</code>
                </p>
                <p style="color: #666;">Check the README.md for setup instructions.</p>
                <a href="index.html" style="display: inline-block; margin-top: 20px; padding: 12px 24px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; text-decoration: none; border-radius: 10px; font-weight: 600;">
                    ← Back to Home
                </a>
            </div>
        </div>
    `;
}
