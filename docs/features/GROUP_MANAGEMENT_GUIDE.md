# Group Management Feature Guide

## Overview
This feature allows you to manage group members and delete groups. Admins have full control over their groups.

## Features Implemented

### 1. View Group Members
- Click on any group in the sidebar to view the chat
- Click the ⚙️ button in the chat header to open Group Settings
- View all members with their roles (admin/member)

### 2. Remove Members (Admin Only)
- As an admin, you can remove any member from your group
- Click the 🗑️ button next to any member's name
- Confirm the removal
- The member will be removed from the group immediately

### 3. Delete Group (Admin Only)
- Open Group Settings by clicking ⚙️ in the chat header
- Scroll down to the "Danger Zone" section
- Click "🗑️ Delete Group"
- Confirm the deletion twice (this is irreversible)
- All group messages will be deleted along with the group

### 4. Leave Group
- Click the 🚪 button in the chat header to leave a group
- Confirm your decision
- You'll be removed from the group but the group will remain

## UI Features

### Chat Header Buttons
When viewing a group chat, the header buttons change:
- ⚙️ - Open Group Settings (view members, delete group)
- 🚪 - Leave Group

When viewing a friend chat:
- 👤 - View Profile
- 🗑️ - Remove Friend

### Group Settings Modal
- Shows group avatar and name
- Lists all members with their roles
- Admin-only actions (remove members, delete group)
- Danger zone for irreversible actions

## Database Permissions

**Important:** You need to run the database migration to enable these features.

Run this SQL in your Supabase SQL Editor:
```sql
database/add-group-management-permissions.sql
```

This adds the following permissions:
- Admins can delete their groups
- Admins can remove other members from groups
- Users can leave groups themselves

## How to Use

### For Admins

1. **View Your Group Members**
   ```
   1. Click on a group in the sidebar
   2. Click ⚙️ in the chat header
   3. View all members in the modal
   ```

2. **Remove a Member**
   ```
   1. Open Group Settings
   2. Find the member you want to remove
   3. Click 🗑️ next to their name
   4. Confirm
   ```

3. **Delete a Group**
   ```
   1. Open Group Settings
   2. Scroll to "Danger Zone"
   3. Click "🗑️ Delete Group"
   4. Confirm twice
   ```

### For Members

1. **Leave a Group**
   ```
   1. Open the group chat
   2. Click 🚪 in the chat header
   3. Confirm you want to leave
   ```

## Security

- Only group admins can delete groups
- Only group admins can remove other members
- All members can leave a group themselves
- Deleted groups cannot be recovered
- All messages are deleted when a group is deleted

## Technical Details

### Files Modified
- `pages/chat.html` - Updated UI, button handlers, message loading
- `js/groups.js` - Added group management functions

### Functions Added
- `openGroupSettings()` - Opens the group settings modal
- `closeGroupSettings()` - Closes the modal
- `loadGroupMembers(groupId)` - Loads all group members
- `renderGroupMembers()` - Renders the member list
- `removeMemberFromGroup(userId, userName)` - Removes a member
- `deleteGroupConfirmation()` - Confirms group deletion
- `deleteGroup(groupId)` - Deletes the group
- `leaveGroupFromChat()` - Wrapper for leaving group
- `subscribeToGroupMessages(groupId)` - Real-time group messages

### Database Changes
New policies added to `groups` and `group_members` tables for:
- Group deletion (admin only)
- Member removal (admin only)
- User can leave groups

## Testing

1. Create a test group
2. Add some members
3. As admin, try removing a member
4. Try leaving the group as a member
5. As admin, try deleting the group

## Future Enhancements

Possible additions:
- Transfer group ownership
- Assign moderators
- Mute/unmute members
- Group announcement feature
- Member invite links
- Group search and discovery

