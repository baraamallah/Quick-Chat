# Background Image Feature

## Overview
Users can now set a custom background image that appears on both the Settings page and the Chat page.

## How It Works

### Setting the Background Image

1. **Go to Settings**
   - Navigate to Settings page
   - Find "Background Image URL" field
   - Enter the URL of your desired image
   - Click "Save Changes"

2. **Supported Formats**
   - Direct image URLs (jpg, png, gif, webp, etc.)
   - Must be publicly accessible
   - HTTPS recommended for security

### Where It Appears

**Settings Page:**
- Full-screen background
- Centered positioning
- 15% opacity overlay
- Blurred effect for readability

**Chat Page:**
- Full-screen background
- Centered positioning (`object-position: center`)
- 15% opacity overlay
- Doesn't interfere with chat UI

## Technical Implementation

### CSS Styling

```css
#chatBgImage {
    position: fixed;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    object-fit: cover;           /* Covers entire viewport */
    object-position: center;     /* Centered alignment */
    opacity: 0.15;               /* Subtle overlay */
    z-index: 0;                  /* Behind all content */
    pointer-events: none;        /* Doesn't block clicks */
}
```

### Key Features

**1. Centered Positioning**
- `object-position: center` ensures image is always centered
- Works with any image size or aspect ratio
- No distortion or stretching

**2. Cover Behavior**
- `object-fit: cover` fills entire viewport
- Maintains aspect ratio
- Crops edges if needed to fill space

**3. Layering**
```
z-index: 0  → Background image
z-index: 1  → Gradient overlay
z-index: 2  → Chat UI content
```

**4. Error Handling**
```javascript
bgImg.onerror = function() {
    this.style.display = 'none';
};
```
- Hides image if URL fails to load
- Graceful fallback to default background

## User Experience

### Visual Hierarchy
1. **Background Image** (bottom layer, 15% opacity)
2. **Gradient Overlay** (adds depth and consistency)
3. **UI Elements** (fully opaque, readable)

### Readability
- Low opacity (15%) ensures text remains readable
- Gradient overlay adds extra contrast
- Semi-transparent UI panels with backdrop blur

### Performance
- Single image element shared across pages
- Lazy loading (only loads when URL is set)
- Cached by browser after first load

## Examples

### Good Image URLs
```
https://images.unsplash.com/photo-1234567890
https://i.imgur.com/abcdefg.jpg
https://example.com/images/background.png
```

### Image Recommendations
- **Resolution:** 1920x1080 or higher
- **Aspect Ratio:** 16:9 works best
- **File Size:** Under 2MB for fast loading
- **Style:** Subtle patterns or gradients work best
- **Avoid:** Busy images with too much detail

## Settings Page vs Chat Page

### Settings Page
```css
#bgImage {
    filter: blur(8px);           /* Blurred effect */
    opacity: 0.15;
}
```

### Chat Page
```css
#chatBgImage {
    filter: none;                /* No blur */
    opacity: 0.15;
}
```

Both use:
- `object-fit: cover`
- `object-position: center`
- Fixed positioning
- Same opacity

## Customization

### Change Opacity
Edit the CSS in `chat.html`:
```css
#chatBgImage {
    opacity: 0.20;  /* Increase for more visible */
}
```

### Add Blur Effect
```css
#chatBgImage {
    filter: blur(5px);
}
```

### Change Positioning
```css
#chatBgImage {
    object-position: top;      /* Top-aligned */
    object-position: bottom;   /* Bottom-aligned */
    object-position: left;     /* Left-aligned */
}
```

## Browser Support

### object-fit and object-position
- ✅ Chrome/Edge (all versions)
- ✅ Firefox (36+)
- ✅ Safari (10+)
- ✅ Opera (all versions)
- ✅ Mobile browsers

### Fallback
If browser doesn't support `object-fit`:
- Image still displays
- May not be perfectly centered
- Still functional

## Privacy & Security

### Considerations
- Images loaded from external URLs
- No images stored on server
- User's browser loads the image
- HTTPS recommended for security

### CORS
- Some image hosts may block cross-origin requests
- Use image hosting services that allow hotlinking
- Test URL before saving

## Troubleshooting

### Image Not Showing?
1. **Check URL**
   - Must be publicly accessible
   - Try opening URL in browser
   - Verify it's a direct image link

2. **Check Console**
   - Open browser DevTools
   - Look for CORS errors
   - Check for 404 errors

3. **Clear Cache**
   - Hard refresh: `Ctrl+Shift+R`
   - Clear browser cache
   - Try different image URL

### Image Too Visible/Invisible?
- Adjust opacity in CSS
- Try different image (lighter/darker)
- Check gradient overlay settings

### Image Not Centered?
- Verify `object-position: center` is set
- Check if image has unusual aspect ratio
- Try different image

## Future Enhancements

Possible improvements:
- Upload images directly (no URL needed)
- Image gallery/presets
- Per-friend background images
- Animated backgrounds
- Parallax effects
- Brightness/contrast controls

## Database Field

Background image URL is stored in:
```sql
users.bg_image_url TEXT
```

- Optional field (can be empty)
- Stores full URL string
- Updated via Settings page

## Summary

✅ **Background images work on Chat page**
✅ **Centered positioning (`object-position: center`)**
✅ **Covers entire viewport (`object-fit: cover`)**
✅ **15% opacity for readability**
✅ **Error handling for invalid URLs**
✅ **No performance impact**
✅ **Works with existing Settings feature**

Users can now personalize their chat experience with custom background images that are properly centered and don't interfere with the UI!
