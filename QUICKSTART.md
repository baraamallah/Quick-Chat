# 🚀 Quick Start Guide

Get your Quick Chat app running in 5 minutes!

## Step 1: Set Up Supabase (2 minutes)

1. Go to [supabase.com](https://supabase.com) and sign in
2. Click **"New Project"**
3. Fill in project details and wait for it to initialize
4. Go to **Project Settings** → **API**
5. Copy these two values:
   - **Project URL** (looks like: `https://xxxxx.supabase.co`)
   - **anon/public key** (long string starting with `eyJ...`)

## Step 2: Create Database Tables (1 minute)

1. In Supabase, go to **SQL Editor**
2. Click **"New Query"**
3. Copy and paste the entire contents of `database/setup.sql`
4. Click **"Run"** or press `Ctrl+Enter`
5. You should see: "Database setup complete! 🎉"

## Step 3: Configure the App (30 seconds)

1. Open `js/config.js` in your text editor
2. Replace these two lines:
   ```javascript
   url: 'YOUR_SUPABASE_URL',        // Paste your Project URL here
   anonKey: 'YOUR_SUPABASE_ANON_KEY' // Paste your anon key here
   ```
3. Save the file

## Step 4: Run the App (30 seconds)

**Option A: Simple (Double-click)**
- Just open `pages/index.html` in your browser

**Option B: Local Server (Recommended)**
```bash
# If you have Python installed:
python -m http.server 8000

# If you have Node.js installed:
npx serve

# Then open: http://localhost:8000/pages/index.html
```

## Step 5: Start Chatting! 🎉

### Create Users (Admin Panel)
1. Go to **Admin Panel** from the home page
2. Create 2-3 users (e.g., "Alice", "Bob", "Charlie")
3. **Copy their friend codes** - you'll need these!

### Add Friends & Chat
1. Go to **Chat** from the home page
2. Select a user (e.g., Alice)
3. Copy Alice's friend code from the sidebar
4. Open another browser tab/window
5. Select Bob and enter Alice's friend code
6. Click ➕ to add friend
7. Now they can chat! 💬

## 🎯 Tips

- **Friend Codes**: Each user gets a unique 6-character code (e.g., `A3K9P2`)
- **Private Chats**: Messages are only visible between friends
- **Real-time**: Messages appear instantly - no refresh needed!
- **Multiple Tabs**: Open multiple browser tabs to simulate different users
- **End Session**: Use the admin panel to clear all data and start fresh

## 🐛 Troubleshooting

**"Configuration Required" error?**
- Make sure you updated `js/config.js` with your Supabase credentials

**Can't add friends?**
- Make sure both users exist in the admin panel
- Friend codes are case-sensitive
- You can't add yourself as a friend

**Messages not appearing?**
- Check that you're friends with the person
- Refresh the page
- Check browser console for errors

**Database errors?**
- Make sure you ran the complete SQL setup script
- Check that all three tables were created (users, friendships, messages)

## 📚 Next Steps

- Customize colors in `css/styles.css`
- Add more features to the chat
- Deploy to a hosting service
- Add authentication for production use

Enjoy your Quick Chat app! 🎉
