# ⚡ Quick Chat - Lightning Fast Chat Application

A modern, real-time chat application with friend codes, private messaging, and admin controls powered by Supabase.

## 🚀 Features

- **Friend Code System**: Add friends using unique 6-character codes
- **Private Messaging**: Chat only with your friends
- **Admin Dashboard**: Create and manage users with auto-generated friend codes
- **Real-time Chat**: Instant messaging with live updates
- **Session Management**: Clear all chat history and database with one click
- **Modern UI**: Beautiful gradient design with smooth animations
- **Super Fast**: Optimized for performance

## 📋 Setup Instructions

### 1. Create Supabase Project

1. Go to [supabase.com](https://supabase.com) and create a new project
2. Once created, go to Project Settings → API
3. Copy your `Project URL` and `anon/public` API key

### 2. Set Up Database

Run this SQL in your Supabase SQL Editor:

```sql
-- Create users table with friend codes
CREATE TABLE users (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  username TEXT UNIQUE NOT NULL,
  display_name TEXT NOT NULL,
  color TEXT NOT NULL,
  friend_code TEXT UNIQUE NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create friendships table
CREATE TABLE friendships (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user1_id UUID REFERENCES users(id) ON DELETE CASCADE,
  user2_id UUID REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user1_id, user2_id)
);

-- Create messages table (private between friends)
CREATE TABLE messages (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  sender_id UUID REFERENCES users(id) ON DELETE CASCADE,
  receiver_id UUID REFERENCES users(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE friendships ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

-- Create policies for public access (adjust as needed for production)
CREATE POLICY "Allow public read access on users" ON users FOR SELECT USING (true);
CREATE POLICY "Allow public insert on users" ON users FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow public delete on users" ON users FOR DELETE USING (true);

CREATE POLICY "Allow public read access on friendships" ON friendships FOR SELECT USING (true);
CREATE POLICY "Allow public insert on friendships" ON friendships FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow public delete on friendships" ON friendships FOR DELETE USING (true);

CREATE POLICY "Allow public read access on messages" ON messages FOR SELECT USING (true);
CREATE POLICY "Allow public insert on messages" ON messages FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow public delete on messages" ON messages FOR DELETE USING (true);

-- Enable Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE users;
ALTER PUBLICATION supabase_realtime ADD TABLE friendships;
ALTER PUBLICATION supabase_realtime ADD TABLE messages;
```

### 3. Configure Application

1. Open `js/config.js`
2. Replace `YOUR_SUPABASE_URL` with your Supabase project URL
3. Replace `YOUR_SUPABASE_ANON_KEY` with your anon/public API key

### 4. Run the Application

Simply open `pages/index.html` in your browser or use a local server:

```bash
# Using Python
python -m http.server 8000

# Using Node.js
npx serve

# Using PHP
php -S localhost:8000
```

Then navigate to:
- **Home**: `pages/index.html`
- **Admin Panel**: `pages/admin.html`
- **Chat Interface**: `pages/chat.html`

## 📁 Project Structure

```
Quick Chat/
├── pages/
│   ├── index.html      # Landing page
│   ├── admin.html      # Admin dashboard
│   └── chat.html       # Chat interface
├── css/
│   └── styles.css      # Global styles
├── js/
│   ├── config.js       # Supabase configuration
│   └── supabase-init.js # Supabase initialization
└── README.md           # This file
```

## 🎨 Usage

### Admin Panel
1. Open `pages/admin.html`
2. Create users by entering username and display name
3. Each user gets a unique 6-character friend code automatically
4. View all active users with their friend codes
5. Delete individual users or end session (clears everything)

### Chat Interface
1. Open `pages/chat.html`
2. Select your user account from the dropdown
3. Your friend code is displayed at the top
4. **Add Friends**: Enter a friend's code and click ➕
5. Click on a friend to start chatting
6. Messages are private - only you and your friend can see them
7. Real-time updates for instant messaging!

## 🛠️ Tech Stack

- **Frontend**: HTML5, CSS3, JavaScript (Vanilla)
- **Backend**: Supabase (PostgreSQL + Realtime)
- **Styling**: Custom CSS with gradients and animations

## 📝 Notes

- All data is stored in Supabase
- Real-time updates using Supabase Realtime
- Friend codes are unique 6-character alphanumeric codes
- Messages are private between friends only
- Session clearing removes all users, friendships, and messages
- No authentication required (adjust RLS policies for production)

## 🔒 Security Note

This is a demo application. For production use:
- Implement proper authentication
- Adjust Row Level Security policies
- Add rate limiting
- Validate all inputs server-side
