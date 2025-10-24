# ⚡ Quick Chat - Modern Messaging Platform

A feature-rich, real-time chat application with groups, image sharing, and mobile-first design powered by Supabase.

## 🚀 Features

### 💬 Messaging
- **Real-time Chat**: Instant messaging with live updates
- **Friend System**: Add friends using unique 6-character codes
- **Group Chats**: Create groups with unique codes, add multiple members
- **Image Sharing**: Upload and share images with captions
- **Private Messages**: Secure one-on-one conversations

### 🎨 Customization
- **Dark/Light Themes**: Toggle between themes with smooth transitions
- **Custom Backgrounds**: Set personal background images
- **Profile Avatars**: Customize your profile with avatars and colors
- **Custom Favicons**: Unique icons for regular and admin pages

### 📱 Mobile-Friendly
- **Responsive Design**: Works perfectly on all devices
- **Touch-Optimized**: 44px+ touch targets, smooth gestures
- **PWA Ready**: Install as an app on mobile devices
- **Fast & Smooth**: Optimized for mobile performance

### 🔒 Security & Admin
- **Row Level Security**: Database-level access control
- **Admin Dashboard**: Comprehensive user and system management
- **Session Management**: Secure authentication and session handling
- **Privacy Controls**: Messages visible only to intended recipients

## 📋 Setup Instructions

### 1. Create Supabase Project

1. Go to [supabase.com](https://supabase.com) and create a new project
2. Once created, go to Project Settings → API
3. Copy your `Project URL` and `anon/public` API key

### 2. Set Up Database

**Important:** Use the complete migration file for all features.

Run the SQL migration in your Supabase SQL Editor:
- **File:** `docs/database/DATABASE_UPDATES.sql`
- **Contains:** All tables, policies, functions, and triggers

Or run the basic setup below (legacy):

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

### 3. Create Storage Bucket

For image sharing:
1. Go to Supabase Storage
2. Create new bucket: `chat-images`
3. Set access to **Public**
4. RLS policies are included in the SQL migration

### 4. Configure Application

1. Open `js/config.js`
2. Replace `YOUR_SUPABASE_URL` with your Supabase project URL
3. Replace `YOUR_SUPABASE_ANON_KEY` with your anon/public API key

### 5. Deploy

**Option 1: Vercel (Recommended)**
```bash
git push origin main
# Vercel auto-deploys!
```

**Option 2: Local Development**
```bash
# Using Python
python -m http.server 8000

# Using Node.js
npx serve
```

## 📁 Project Structure

```
Quick Chat/
├── docs/                      # 📚 Documentation
│   ├── README.md             # Documentation index
│   ├── features/             # Feature documentation
│   ├── guides/               # Implementation guides
│   └── database/             # SQL migrations
├── pages/                     # HTML pages
│   ├── index.html            # Landing page
│   ├── auth.html             # Authentication
│   ├── chat.html             # Main chat interface
│   ├── settings.html         # User settings
│   ├── admin.html            # Admin dashboard
│   └── admin-login.html      # Admin login
├── css/                       # Stylesheets
│   ├── dark-theme.css        # Main theme
│   ├── theme-system.css      # Theme toggle
│   ├── mobile.css            # Mobile responsive
│   ├── images.css            # Image UI
│   └── groups.css            # Groups UI
├── js/                        # JavaScript
│   ├── config.js             # Configuration
│   ├── supabase-init.js      # Supabase setup
│   ├── theme-toggle.js       # Theme switching
│   ├── images.js             # Image handling
│   └── groups.js             # Groups system
├── favicon.svg                # App icon
├── favicon-admin.svg          # Admin icon
└── README.md                  # This file
```

## 🎨 Usage

### Getting Started
1. **Sign Up**: Create your account at `pages/auth.html`
2. **Add Friends**: Use their 6-character friend code
3. **Start Chatting**: Select a friend and send messages
4. **Create Groups**: Click + in Groups section
5. **Share Images**: Click 📎 to attach images

### Friend System
- Each user gets a unique 6-character code
- Share your code with friends
- Add friends using their codes
- View friend profiles by clicking their name

### Group Chats
- Create groups with unique codes
- Add members using friend codes
- Chat with multiple people
- Admin controls for group management

### Image Sharing
- Click 📎 attachment button
- Select image from device
- Add optional caption
- Send to friends or groups
- View full-size images
- Download shared images

### Customization
- Toggle dark/light theme (☀️/🌙 button)
- Set custom background image
- Customize profile avatar
- Choose your color theme

### Mobile Usage
- Swipe to open/close sidebar
- Touch-friendly buttons
- Optimized for all screen sizes
- Install as PWA on mobile

## 🛠️ Tech Stack

- **Frontend**: HTML5, CSS3, JavaScript (Vanilla)
- **Backend**: Supabase (PostgreSQL + Realtime + Storage)
- **Styling**: Custom CSS with responsive design
- **Hosting**: Vercel (recommended)
- **Database**: PostgreSQL with Row Level Security
- **Storage**: Supabase Storage for images
- **Real-time**: Supabase Realtime subscriptions

## 📚 Documentation

Complete documentation available in `docs/`:

- **[Documentation Index](docs/README.md)** - Start here
- **[Implementation Guide](docs/guides/IMPLEMENTATION_GUIDE.md)** - Setup instructions
- **[Deployment Checklist](docs/guides/DEPLOYMENT_CHECKLIST.md)** - Launch guide
- **[Features Implemented](docs/features/FEATURES_IMPLEMENTED.md)** - Feature list
- **[Database Schema](docs/database/DATABASE_UPDATES.sql)** - Complete SQL

## 📝 Notes

- All data is stored in Supabase
- Real-time updates using Supabase Realtime
- Images stored in Supabase Storage
- Friend codes are unique 6-character alphanumeric codes
- Group codes are auto-generated unique 6-character codes
- Messages are private (DM) or group-based
- Row Level Security enforces access control
- Mobile-first responsive design

## 🔒 Security

**Built-in Security:**
- Row Level Security (RLS) on all tables
- Secure authentication with Supabase Auth
- Private messages visible only to participants
- Group messages visible only to members
- Image upload validation (size, type)
- Secure file storage with access control

**For Production:**
- ✅ RLS policies already configured
- ✅ Secure authentication implemented
- ✅ Input validation on frontend
- ⚠️ Consider rate limiting
- ⚠️ Monitor storage usage
- ⚠️ Set up error tracking

## 🚀 Deployment

**Quick Deploy:**
```bash
# 1. Run database migration
# See: docs/database/DATABASE_UPDATES.sql

# 2. Create storage bucket
# Bucket name: chat-images (Public)

# 3. Deploy to Vercel
git push origin main
```

**Full deployment guide:** [docs/guides/DEPLOYMENT_CHECKLIST.md](docs/guides/DEPLOYMENT_CHECKLIST.md)

## 🤝 Contributing

Contributions welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add documentation
5. Submit a pull request

## 📄 License

MIT License - feel free to use for personal or commercial projects

## 🙏 Acknowledgments

Built with:
- [Supabase](https://supabase.com) - Backend & Database
- [Vercel](https://vercel.com) - Hosting
- Modern web technologies

---

**Ready to chat?** 🚀 [Get Started](docs/guides/IMPLEMENTATION_GUIDE.md)
