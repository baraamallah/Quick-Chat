# Vercel Deployment Guide

## Quick Chat - Deployment Instructions

### Prerequisites
- A Vercel account (sign up at [vercel.com](https://vercel.com))
- Your Supabase credentials ready

### Deployment Steps

1. **Install Vercel CLI (Optional)**
   ```bash
   npm i -g vercel
   ```

2. **Deploy via Vercel CLI**
   ```bash
   cd "d:\gemini-cli\Quick Chat"
   vercel
   ```
   
   Or deploy via **Vercel Dashboard**:
   - Go to [vercel.com/new](https://vercel.com/new)
   - Import your Git repository or drag & drop the project folder
   - Click "Deploy"

3. **Configure Environment Variables**
   
   After deployment, you need to update your Supabase configuration in `js/config.js`:
   
   - Replace the placeholder values with your actual Supabase credentials:
     ```javascript
     const SUPABASE_URL = 'your-actual-supabase-url';
     const SUPABASE_ANON_KEY = 'your-actual-supabase-anon-key';
     ```

### Project Structure

```
Quick Chat/
├── index.html              # Root landing page (entry point)
├── pages/                  # All application pages
│   ├── auth.html          # Authentication page
│   ├── chat.html          # Main chat interface
│   ├── settings.html      # User settings
│   ├── admin.html         # Admin panel
│   └── admin-login.html   # Admin login
├── css/                   # Stylesheets
├── js/                    # JavaScript files
├── vercel.json           # Vercel configuration
└── .vercelignore         # Files to exclude from deployment
```

### Routing Configuration

All internal navigation uses absolute paths starting with `/pages/` to ensure proper routing on Vercel:
- `/` → `index.html` (landing page)
- `/pages/auth.html` → Authentication
- `/pages/chat.html` → Chat interface
- `/pages/settings.html` → Settings
- `/pages/admin.html` → Admin panel
- `/pages/admin-login.html` → Admin login

### Post-Deployment Checklist

- [ ] Verify the landing page loads correctly
- [ ] Test authentication flow (sign up/sign in)
- [ ] Check chat functionality
- [ ] Test settings page
- [ ] Verify admin panel access (if applicable)
- [ ] Ensure all navigation links work properly
- [ ] Test on mobile devices
- [ ] Check Vercel Analytics dashboard for tracking
- [ ] Verify Core Web Vitals scores

### Troubleshooting

**Issue: Pages not loading**
- Check that all paths use `/pages/` prefix
- Verify `vercel.json` is in the root directory

**Issue: Authentication not working**
- Confirm Supabase credentials in `js/config.js`
- Check Supabase dashboard for allowed redirect URLs
- Add your Vercel domain to Supabase Auth settings

**Issue: 404 errors**
- Ensure all file paths are absolute (start with `/`)
- Check that files exist in the correct directories

### Support

For issues or questions, refer to:
- [Vercel Documentation](https://vercel.com/docs)
- [Supabase Documentation](https://supabase.com/docs)
