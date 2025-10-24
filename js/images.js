// Image Upload and Viewer System

const MAX_FILE_SIZE = 5 * 1024 * 1024; // 5MB
const ALLOWED_TYPES = ['image/jpeg', 'image/png', 'image/gif', 'image/webp'];

// Validate image file
function validateImageFile(file) {
    if (!file) {
        throw new Error('No file selected');
    }
    
    if (file.size > MAX_FILE_SIZE) {
        throw new Error('File too large (max 5MB)');
    }
    
    if (!ALLOWED_TYPES.includes(file.type)) {
        throw new Error('Invalid file type. Use JPG, PNG, GIF, or WebP');
    }
    
    return true;
}

// Upload image to Supabase Storage
async function uploadImage(file) {
    try {
        validateImageFile(file);
        
        const fileExt = file.name.split('.').pop();
        const fileName = `${Date.now()}_${Math.random().toString(36).substring(7)}.${fileExt}`;
        const filePath = `${currentUser.id}/${fileName}`;
        
        // Show upload progress
        showNotification('Uploading image...', 'info');
        
        const { data, error } = await supabaseClient.storage
            .from('chat-images')
            .upload(filePath, file);
        
        if (error) throw error;
        
        // Get public URL
        const { data: { publicUrl } } = supabaseClient.storage
            .from('chat-images')
            .getPublicUrl(filePath);
        
        return publicUrl;
    } catch (error) {
        console.error('Upload error:', error);
        showNotification(error.message || 'Failed to upload image', 'error');
        throw error;
    }
}

// Send image message
async function sendImageMessage(imageUrl, caption = '') {
    if (!selectedFriend) {
        showNotification('Please select a friend first', 'error');
        return;
    }
    
    try {
        const { error } = await supabaseClient
            .from('messages')
            .insert({
                sender_id: currentUser.id,
                receiver_id: selectedFriend.id,
                message_type: 'image',
                image_url: imageUrl,
                content: caption
            });
        
        if (error) throw error;
        
        showNotification('Image sent!', 'success');
    } catch (error) {
        console.error('Send error:', error);
        showNotification('Failed to send image', 'error');
    }
}

// Handle image selection
async function handleImageSelect(event) {
    const file = event.target.files[0];
    if (!file) return;
    
    try {
        // Upload image
        const imageUrl = await uploadImage(file);
        
        // Show preview and get caption
        showImagePreview(imageUrl, file.name);
        
    } catch (error) {
        console.error('Image select error:', error);
    }
}

// Show image preview before sending
function showImagePreview(imageUrl, fileName) {
    const modal = document.getElementById('imagePreviewModal');
    const img = document.getElementById('previewImage');
    const nameEl = document.getElementById('previewFileName');
    const captionInput = document.getElementById('imageCaption');
    
    img.src = imageUrl;
    nameEl.textContent = fileName;
    captionInput.value = '';
    
    modal.classList.add('active');
    
    // Store URL for sending
    modal.dataset.imageUrl = imageUrl;
}

// Send previewed image
async function sendPreviewedImage() {
    const modal = document.getElementById('imagePreviewModal');
    const imageUrl = modal.dataset.imageUrl;
    const caption = document.getElementById('imageCaption').value.trim();
    
    await sendImageMessage(imageUrl, caption);
    closeImagePreview();
}

// Close image preview
function closeImagePreview() {
    const modal = document.getElementById('imagePreviewModal');
    modal.classList.remove('active');
    modal.dataset.imageUrl = '';
    document.getElementById('imageCaption').value = '';
}

// Open image viewer (full size)
function openImageViewer(imageUrl, senderName = '', timestamp = '', caption = '') {
    const modal = document.getElementById('imageViewerModal');
    const img = document.getElementById('viewerImage');
    const sender = document.getElementById('viewerSender');
    const time = document.getElementById('viewerTime');
    const captionEl = document.getElementById('viewerCaption');
    
    img.src = imageUrl;
    sender.textContent = senderName;
    time.textContent = timestamp;
    
    if (caption) {
        captionEl.textContent = caption;
        captionEl.style.display = 'block';
    } else {
        captionEl.style.display = 'none';
    }
    
    modal.classList.add('active');
    modal.dataset.imageUrl = imageUrl;
}

// Close image viewer
function closeImageViewer() {
    const modal = document.getElementById('imageViewerModal');
    modal.classList.remove('active');
}

// Download image
function downloadImage() {
    const modal = document.getElementById('imageViewerModal');
    const imageUrl = modal.dataset.imageUrl;
    
    if (!imageUrl) return;
    
    const link = document.createElement('a');
    link.href = imageUrl;
    link.download = `image_${Date.now()}.jpg`;
    link.click();
}

// Render image message
function renderImageMessage(message, isSent) {
    const time = new Date(message.created_at).toLocaleTimeString('en-US', {
        hour: 'numeric',
        minute: '2-digit'
    });
    
    const senderName = isSent ? 'You' : (selectedFriend ? selectedFriend.display_name : 'Friend');
    
    return `
        <div class="message ${isSent ? 'sent' : ''}">
            ${!isSent ? `<div class="message-avatar avatar avatar-sm" style="background: ${selectedFriend?.color || '#667eea'}">${selectedFriend?.display_name?.charAt(0)?.toUpperCase() || 'F'}</div>` : ''}
            <div class="message-content">
                <img 
                    src="${escapeHtml(message.image_url)}" 
                    class="message-image"
                    onclick="openImageViewer('${escapeHtml(message.image_url)}', '${escapeHtml(senderName)}', '${time}', '${escapeHtml(message.content || '')}')"
                    loading="lazy"
                    alt="Shared image"
                />
                ${message.content ? `<div class="message-text">${escapeHtml(message.content)}</div>` : ''}
                <div class="message-time">${time}</div>
            </div>
            ${isSent ? `<div class="message-avatar avatar avatar-sm" style="background: ${currentUser.color}">${currentUser.display_name.charAt(0).toUpperCase()}</div>` : ''}
        </div>
    `;
}

// Open attachment menu
function openAttachmentMenu() {
    const menu = document.getElementById('attachmentMenu');
    menu.classList.add('active');
}

// Close attachment menu
function closeAttachmentMenu() {
    const menu = document.getElementById('attachmentMenu');
    menu.classList.remove('active');
}

// Trigger file input
function selectImage() {
    closeAttachmentMenu();
    document.getElementById('imageFileInput').click();
}
