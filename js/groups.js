// Groups System

let groups = [];
let selectedGroup = null;

// Load user's groups
async function loadGroups() {
    try {
        const { data, error } = await supabaseClient
            .from('group_members')
            .select(`
                group_id,
                role,
                groups (
                    id,
                    name,
                    description,
                    group_code,
                    avatar_url,
                    color,
                    created_by
                )
            `)
            .eq('user_id', currentUser.id);
        
        if (error) throw error;
        
        groups = data.map(item => ({
            ...item.groups,
            user_role: item.role
        }));
        
        renderGroups();
    } catch (error) {
        console.error('Load groups error:', error);
        showNotification('Failed to load groups', 'error');
    }
}

// Render groups in sidebar
function renderGroups() {
    const container = document.getElementById('groupsList');
    if (!container) return;
    
    if (groups.length === 0) {
        container.innerHTML = `
            <div class="empty-state">
                <div class="empty-state-icon">👥</div>
                <div class="empty-state-text">No groups yet</div>
            </div>
        `;
        return;
    }
    
    container.innerHTML = groups.map(group => {
        const isActive = selectedGroup && selectedGroup.id === group.id;
        const avatarContent = group.avatar_url 
            ? `<img src="${escapeHtml(group.avatar_url)}" alt="${escapeHtml(group.name)}">` 
            : group.name.charAt(0).toUpperCase();
        
        return `
            <div class="group-item ${isActive ? 'active' : ''}" onclick="selectGroup('${group.id}')">
                <div class="avatar avatar-sm" style="background: ${group.color}">
                    ${avatarContent}
                </div>
                <div class="group-item-info">
                    <div class="group-name">${escapeHtml(group.name)}</div>
                    <div class="group-code">${group.group_code}</div>
                </div>
            </div>
        `;
    }).join('');
}

// Select a group
async function selectGroup(groupId) {
    const group = groups.find(g => g.id === groupId);
    if (!group) return;
    
    selectedGroup = group;
    selectedFriend = null; // Clear friend selection
    messages = []; // Clear previous messages
    
    // Unsubscribe from friend messages if any
    if (typeof messageSubscription !== 'undefined' && messageSubscription) {
        messageSubscription.unsubscribe();
        messageSubscription = null;
    }
    
    // Update UI
    renderGroups();
    renderFriends();
    
    // Show group chat
    document.getElementById('emptyChat').style.display = 'none';
    document.getElementById('chatView').style.display = 'flex';
    
    // Update header with proper styling cleanup
    const avatar = document.getElementById('chatFriendAvatar');
    avatar.style.background = ''; // Reset
    avatar.style.color = '';
    
    const avatarContent = group.avatar_url 
        ? `<img src="${escapeHtml(group.avatar_url)}" alt="${escapeHtml(group.name)}">` 
        : group.name.charAt(0).toUpperCase();
    
    avatar.innerHTML = avatarContent;
    avatar.style.background = group.color;
    document.getElementById('chatFriendName').textContent = group.name;
    document.getElementById('chatFriendStatus').textContent = `Group • ${group.group_code}`;
    
    // Update chat actions
    if (typeof updateChatActions === 'function') {
        updateChatActions();
    }
    
    // Load group messages
    await loadGroupMessages(groupId);
}

// Load group messages
async function loadGroupMessages(groupId) {
    try {
        const { data, error } = await supabaseClient
            .from('messages')
            .select(`
                *,
                sender:users!messages_sender_id_fkey(id, display_name, avatar_url, color)
            `)
            .eq('group_id', groupId)
            .order('created_at', { ascending: true });
        
        if (error) throw error;
        
        messages = data;
        renderGroupMessages();
        
        // Mark as read
        await updateGroupLastRead(groupId);
        
        // Subscribe to new group messages
        subscribeToGroupMessages(groupId);
    } catch (error) {
        console.error('Load group messages error:', error);
        showNotification('Failed to load messages', 'error');
    }
}

// Subscribe to group messages
function subscribeToGroupMessages(groupId) {
    // Unsubscribe from previous if exists
    if (window.groupMessageSubscription) {
        window.groupMessageSubscription.unsubscribe();
        window.groupMessageSubscription = null;
    }
    
    // Only subscribe if we're still viewing this group
    if (!selectedGroup || selectedGroup.id !== groupId) return;
    
    window.groupMessageSubscription = supabaseClient
        .channel(`group-messages-${groupId}`)
        .on('postgres_changes', {
            event: 'INSERT',
            schema: 'public',
            table: 'messages',
            filter: `group_id=eq.${groupId}`
        }, async (payload) => {
            // Double-check we're still viewing this group
            if (!selectedGroup || selectedGroup.id !== groupId) return;
            
            const message = payload.new;
            
            // Check if message already exists (prevent duplicates)
            if (messages.some(m => m.id === message.id)) return;
            
            // Fetch sender info
            const { data: sender } = await supabaseClient
                .from('users')
                .select('id, display_name, avatar_url, color')
                .eq('id', message.sender_id)
                .single();
            
            message.sender = sender;
            messages.push(message);
            
            if (typeof renderGroupMessages === 'function') {
                renderGroupMessages();
            }
            
            // Mark as read
            await updateGroupLastRead(groupId);
        })
        .subscribe();
}

// Render group messages
function renderGroupMessages() {
    const container = document.getElementById('messagesContainer');
    if (!container) return;
    
    container.innerHTML = messages.map(message => {
        const isSent = message.sender_id === currentUser.id;
        const sender = message.sender;
        const time = new Date(message.created_at).toLocaleTimeString('en-US', {
            hour: 'numeric',
            minute: '2-digit'
        });
        
        if (message.message_type === 'image') {
            return renderGroupImageMessage(message, isSent, sender, time);
        }
        
        const avatarContent = sender.avatar_url 
            ? `<img src="${escapeHtml(sender.avatar_url)}" alt="${escapeHtml(sender.display_name)}">` 
            : sender.display_name.charAt(0).toUpperCase();
        
        return `
            <div class="message ${isSent ? 'sent' : ''}">
                ${!isSent ? `
                    <div class="message-avatar avatar avatar-sm" style="background: ${sender.color}">
                        ${avatarContent}
                    </div>
                ` : ''}
                <div class="message-content">
                    ${!isSent ? `<div class="message-sender">${escapeHtml(sender.display_name)}</div>` : ''}
                    <div class="message-text">${escapeHtml(message.content)}</div>
                    <div class="message-time">${time}</div>
                </div>
                ${isSent ? `
                    <div class="message-avatar avatar avatar-sm" style="background: ${currentUser.color}">
                        ${currentUser.display_name.charAt(0).toUpperCase()}
                    </div>
                ` : ''}
            </div>
        `;
    }).join('');
    
    container.scrollTop = container.scrollHeight;
}

// Render group image message
function renderGroupImageMessage(message, isSent, sender, time) {
    const avatarContent = sender.avatar_url 
        ? `<img src="${escapeHtml(sender.avatar_url)}" alt="${escapeHtml(sender.display_name)}">` 
        : sender.display_name.charAt(0).toUpperCase();
    
    return `
        <div class="message ${isSent ? 'sent' : ''}">
            ${!isSent ? `
                <div class="message-avatar avatar avatar-sm" style="background: ${sender.color}">
                    ${avatarContent}
                </div>
            ` : ''}
            <div class="message-content">
                ${!isSent ? `<div class="message-sender">${escapeHtml(sender.display_name)}</div>` : ''}
                <img 
                    src="${escapeHtml(message.image_url)}" 
                    class="message-image"
                    onclick="openImageViewer('${escapeHtml(message.image_url)}', '${escapeHtml(sender.display_name)}', '${time}', '${escapeHtml(message.content || '')}')"
                    loading="lazy"
                    alt="Shared image"
                />
                ${message.content ? `<div class="message-text">${escapeHtml(message.content)}</div>` : ''}
                <div class="message-time">${time}</div>
            </div>
            ${isSent ? `
                <div class="message-avatar avatar avatar-sm" style="background: ${currentUser.color}">
                    ${currentUser.display_name.charAt(0).toUpperCase()}
                </div>
            ` : ''}
        </div>
    `;
}

// Send group message
async function sendGroupMessage(content, messageType = 'text', imageUrl = null) {
    if (!selectedGroup) return;
    
    try {
        const messageData = {
            sender_id: currentUser.id,
            group_id: selectedGroup.id,
            message_type: messageType,
            content: content
        };
        
        if (messageType === 'image' && imageUrl) {
            messageData.image_url = imageUrl;
        }
        
        const { error } = await supabaseClient
            .from('messages')
            .insert(messageData);
        
        if (error) throw error;
    } catch (error) {
        console.error('Send group message error:', error);
        showNotification('Failed to send message', 'error');
    }
}

// Update group last read
async function updateGroupLastRead(groupId) {
    try {
        await supabaseClient
            .from('group_members')
            .update({ last_read_at: new Date().toISOString() })
            .eq('group_id', groupId)
            .eq('user_id', currentUser.id);
    } catch (error) {
        console.error('Update last read error:', error);
    }
}

// Create new group
async function createGroup(name, description = '') {
    try {
        if (!name || name.trim().length === 0) {
            throw new Error('Group name is required');
        }
        
        // Create group
        const { data: group, error: groupError } = await supabaseClient
            .from('groups')
            .insert({
                name: name.trim(),
                description: description.trim(),
                created_by: currentUser.id,
                color: `#${Math.floor(Math.random()*16777215).toString(16)}`
            })
            .select()
            .single();
        
        if (groupError) throw groupError;
        
        // Note: Creator is automatically added as admin by database trigger
        
        showNotification(`Group "${name}" created!`, 'success');
        await loadGroups();
        closeCreateGroupModal();
        
        return group;
    } catch (error) {
        console.error('Create group error:', error);
        showNotification(error.message || 'Failed to create group', 'error');
    }
}

// Add member to group
async function addMemberToGroup(groupId, friendCode) {
    try {
        // Find user by friend code
        const { data: user, error: userError } = await supabaseClient
            .from('users')
            .select('id, display_name')
            .eq('friend_code', friendCode.toUpperCase())
            .single();
        
        if (userError || !user) {
            throw new Error('User not found with that friend code');
        }
        
        // Check if already a member
        const { data: existing } = await supabaseClient
            .from('group_members')
            .select('id')
            .eq('group_id', groupId)
            .eq('user_id', user.id)
            .single();
        
        if (existing) {
            throw new Error('User is already a member');
        }
        
        // Add to group
        const { error } = await supabaseClient
            .from('group_members')
            .insert({
                group_id: groupId,
                user_id: user.id,
                role: 'member'
            });
        
        if (error) throw error;
        
        showNotification(`${user.display_name} added to group!`, 'success');
    } catch (error) {
        console.error('Add member error:', error);
        showNotification(error.message || 'Failed to add member', 'error');
    }
}

// Leave group
async function leaveGroup(groupId) {
    if (!confirm('Are you sure you want to leave this group?')) return;
    
    try {
        const { error } = await supabaseClient
            .from('group_members')
            .delete()
            .eq('group_id', groupId)
            .eq('user_id', currentUser.id);
        
        if (error) throw error;
        
        showNotification('Left group', 'success');
        selectedGroup = null;
        await loadGroups();
        
        // Show empty chat
        document.getElementById('chatView').style.display = 'none';
        document.getElementById('emptyChat').style.display = 'flex';
    } catch (error) {
        console.error('Leave group error:', error);
        showNotification('Failed to leave group', 'error');
    }
}

// Open create group modal
function openCreateGroupModal() {
    document.getElementById('createGroupModal').classList.add('active');
}

// Close create group modal
function closeCreateGroupModal() {
    document.getElementById('createGroupModal').classList.remove('active');
    document.getElementById('groupName').value = '';
    document.getElementById('groupDescription').value = '';
}

// Handle create group form
async function handleCreateGroup() {
    const name = document.getElementById('groupName').value.trim();
    const description = document.getElementById('groupDescription').value.trim();
    
    if (!name) {
        showNotification('Please enter a group name', 'error');
        return;
    }
    
    await createGroup(name, description);
}

// Global variables for group management
let groupMembers = [];
let currentUserGroupRole = null;

// Open group settings modal
async function openGroupSettings() {
    if (!selectedGroup) return;
    
    document.getElementById('groupSettingsModal').classList.add('active');
    
    // Set group info
    const avatarContent = selectedGroup.avatar_url 
        ? `<img src="${escapeHtml(selectedGroup.avatar_url)}" alt="${escapeHtml(selectedGroup.name)}">` 
        : selectedGroup.name.charAt(0).toUpperCase();
    
    document.getElementById('groupSettingsAvatar').innerHTML = avatarContent;
    document.getElementById('groupSettingsAvatar').style.background = selectedGroup.color;
    document.getElementById('groupSettingsName').textContent = selectedGroup.name;
    document.getElementById('groupSettingsCode').textContent = selectedGroup.group_code;
    
    // Load group members
    await loadGroupMembers(selectedGroup.id);
}

// Close group settings modal
function closeGroupSettings() {
    const modal = document.getElementById('groupSettingsModal');
    if (modal) {
        modal.classList.remove('active');
    }
    
    // Clear modal data
    groupMembers = [];
    currentUserGroupRole = null;
}

// Load group members
async function loadGroupMembers(groupId) {
    try {
        const { data, error } = await supabaseClient
            .from('group_members')
            .select(`
                role,
                joined_at,
                user:users!group_members_user_id_fkey(
                    id,
                    display_name,
                    avatar_url,
                    color,
                    username
                )
            `)
            .eq('group_id', groupId);
        
        if (error) throw error;
        
        groupMembers = data || [];
        
        // Find current user's role
        const currentUserMember = groupMembers.find(m => m.user.id === currentUser.id);
        currentUserGroupRole = currentUserMember ? currentUserMember.role : null;
        
        renderGroupMembers();
    } catch (error) {
        console.error('Load group members error:', error);
        showNotification('Failed to load members', 'error');
    }
}

// Render group members
function renderGroupMembers() {
    const container = document.getElementById('groupMembersList');
    
    if (!groupMembers.length) {
        container.innerHTML = `
            <div class="empty-state">
                <div class="empty-state-text">No members</div>
            </div>
        `;
        return;
    }
    
    container.innerHTML = groupMembers.map(member => {
        const isCurrentUser = member.user.id === currentUser.id;
        const isAdmin = currentUserGroupRole === 'admin';
        const canRemove = isAdmin && !isCurrentUser;
        
        const avatarContent = member.user.avatar_url 
            ? `<img src="${escapeHtml(member.user.avatar_url)}" alt="${escapeHtml(member.user.display_name)}">` 
            : member.user.display_name.charAt(0).toUpperCase();
        
        return `
            <div class="member-item">
                <div class="avatar avatar-sm" style="background: ${member.user.color}">
                    ${avatarContent}
                </div>
                <div class="member-info">
                    <div class="member-name">${escapeHtml(member.user.display_name)}${isCurrentUser ? ' (You)' : ''}</div>
                    <div class="member-role ${member.role}">${member.role}</div>
                </div>
                ${canRemove ? `
                    <button class="icon-btn" onclick="removeMemberFromGroup('${member.user.id}', '${member.user.display_name}')" title="Remove Member">
                        🗑️
                    </button>
                ` : ''}
            </div>
        `;
    }).join('');
}

// Remove member from group
async function removeMemberFromGroup(userId, userName) {
    if (!selectedGroup) return;
    
    if (!confirm(`Are you sure you want to remove ${userName} from ${selectedGroup.name}?`)) return;
    
    try {
        const { error } = await supabaseClient
            .from('group_members')
            .delete()
            .eq('group_id', selectedGroup.id)
            .eq('user_id', userId);
        
        if (error) throw error;
        
        showNotification(`${userName} removed from group`, 'success');
        await loadGroupMembers(selectedGroup.id);
        
        // If current user was removed, refresh groups
        if (userId === currentUser.id) {
            await loadGroups();
            selectedGroup = null;
            document.getElementById('chatView').style.display = 'none';
            document.getElementById('emptyChat').style.display = 'flex';
        }
    } catch (error) {
        console.error('Remove member error:', error);
        showNotification('Failed to remove member', 'error');
    }
}

// Delete group confirmation
async function deleteGroupConfirmation() {
    if (!selectedGroup) return;
    
    if (!confirm(`Are you sure you want to delete "${selectedGroup.name}"? This will delete all messages and cannot be undone.`)) return;
    if (!confirm('This action cannot be reversed. Continue?')) return;
    
    await deleteGroup(selectedGroup.id);
}

// Delete group
async function deleteGroup(groupId) {
    try {
        const { error } = await supabaseClient
            .from('groups')
            .delete()
            .eq('id', groupId);
        
        if (error) throw error;
        
        showNotification('Group deleted successfully', 'success');
        closeGroupSettings();
        
        // Reset chat view
        selectedGroup = null;
        document.getElementById('chatView').style.display = 'none';
        document.getElementById('emptyChat').style.display = 'flex';
        
        // Reload groups
        await loadGroups();
    } catch (error) {
        console.error('Delete group error:', error);
        showNotification('Failed to delete group', 'error');
    }
}

// Leave group from chat (wrapper)
async function leaveGroupFromChat() {
    if (!selectedGroup) return;
    await leaveGroup(selectedGroup.id);
}
