# User Verification Feature

## Overview
Instagram-style user verification system where only admins can verify users. Verified users get a blue checkmark badge next to their name throughout the app.

## Features

### 1. Database Schema
- Added `is_verified` boolean column to `users` table
- Default value is `false`
- Only admins can update this column

### 2. Admin Panel
- New "Verified" column in the users table
- "Verify" / "✓ Verified" button for each user
- Click to toggle verification status
- Shows current verification status with green checkmark

### 3. UI Elements

**Verification Badge:**
- Blue gradient background (#667eea to #764ba2)
- White checkmark (✓)
- Appears next to verified users' names
- Hover to see "Verified Account" tooltip

**Where Badge Appears:**
- Friends list in sidebar
- Chat header (next to name)
- Profile modal
- Group member lists
- Admin panel

### 4. Security
- Only admins can verify/unverify users
- Users cannot verify themselves
- Verification status is visible to all users
- Database-level RLS policies enforce permissions

## Database Migration

Run this SQL in your Supabase SQL Editor:
```sql
database/add-verification-feature.sql
```

This will:
- Add `is_verified` column to `users` table
- Set up RLS policies for verification updates
- Automatically verify the first admin
- Create indexes for performance

## Usage

### For Admins

**Verify a User:**
1. Go to Admin Panel
2. Find the user in the table
3. Click the "Verify" button
4. Confirm the action
5. User will now have a verification badge

**Unverify a User:**
1. Go to Admin Panel
2. Find the verified user
3. Click the "✓ Verified" button
4. Confirm the action
5. Badge will be removed

### For Users

The verification badge automatically appears next to verified users:
- In the friends list
- In chat headers
- In profile modals
- In group member lists

## UI Components

### Badge Styles
- **Small**: 12-14px for chat messages and member lists
- **Medium**: 18px for friends list
- **Large**: 20px for profile modals
- **Header**: 16px for chat headers

### Color Scheme
- Gradient: `linear-gradient(135deg, #667eea 0%, #764ba2 100%)`
- Shadow: `0 2px 8px rgba(102, 126, 234, 0.4)`
- White checkmark symbol

### Tooltip
Hovering over the badge shows:
- "Verified Account" tooltip
- Dark background with rounded corners
- Small arrow pointing to badge

## Files Modified

1. **database/add-verification-feature.sql** - Database migration
2. **css/verification.css** - Badge styling
3. **pages/admin.html** - Admin verification controls
4. **pages/chat.html** - Display badges in UI

## Technical Details

### RLS Policies

**Users can update their own profile** (except verification):
```sql
CREATE POLICY "Users can update own profile" ON users
    FOR UPDATE
    USING (id = auth.uid())
    WITH CHECK (
        id = auth.uid() AND
        (OLD.is_verified IS NOT DISTINCT FROM NEW.is_verified)
    );
```

**Admins can update verification status:**
```sql
CREATE POLICY "Admins can update verification" ON users
    FOR UPDATE
    USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'))
    WITH CHECK (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'));
```

### JavaScript Functions

**Toggle Verification:**
```javascript
async function toggleVerification(userId, isCurrentlyVerified) {
    const action = isCurrentlyVerified ? 'unverify' : 'verify';
    
    if (!confirm(`Are you sure you want to ${action} this user?`)) return;

    const { error } = await supabaseClient
        .from('users')
        .update({ is_verified: !isCurrentlyVerified })
        .eq('id', userId);

    if (error) throw error;
    
    showNotification(`User ${action}d successfully`, 'success');
    loadUsers();
}
```

## Future Enhancements

1. **Verification Requests**: Users can request verification from admins
2. **Verification Criteria**: Show reasons for verification
3. **Verified Users List**: Special page showing all verified users
4. **Custom Badges**: Different badges for different user types
5. **Verification History**: Track when and by whom users were verified

## Testing

1. **Verify a User:**
   - Admin clicks "Verify" button
   - Badge should appear immediately in admin panel
   - Badge should appear in chat UI when talking to that user

2. **Unverify a User:**
   - Admin clicks "✓ Verified" button
   - Badge should be removed
   - Verify changes across all UI elements

3. **Visual Consistency:**
   - Check badge appears in friends list
   - Check badge appears in chat header
   - Check badge appears in profile modal
   - Check badge appears in admin panel

