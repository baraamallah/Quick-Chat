// Client-side encryption for API keys
// Note: This is a basic implementation for demonstration purposes
// In a production environment, you should use more robust encryption

class ApiKeyEncryption {
  constructor() {
    // In a real implementation, this key should be derived from user password or biometrics
    // For demo purposes, we'll use a simple approach
    this.encryptionKey = 'quickchat-api-key-encryption-key-v1';
  }
  
  // Simple XOR encryption (NOT secure for production use)
  // This is just for demonstration - in production use AES or similar
  simpleEncrypt(text, key = this.encryptionKey) {
    if (!text) return null;
    
    const textChars = text.split('').map(char => char.charCodeAt(0));
    const keyChars = key.split('').map(char => char.charCodeAt(0));
    
    const encrypted = textChars.map((char, index) => {
      return String.fromCharCode(char ^ keyChars[index % keyChars.length]);
    }).join('');
    
    // Base64 encode to make it safe for storage
    return btoa(encrypted);
  }
  
  // Simple XOR decryption
  simpleDecrypt(encryptedText, key = this.encryptionKey) {
    if (!encryptedText) return null;
    
    try {
      // Base64 decode
      const decoded = atob(encryptedText);
      
      const textChars = decoded.split('').map(char => char.charCodeAt(0));
      const keyChars = key.split('').map(char => char.charCodeAt(0));
      
      const decrypted = textChars.map((char, index) => {
        return String.fromCharCode(char ^ keyChars[index % keyChars.length]);
      }).join('');
      
      return decrypted;
    } catch (error) {
      console.error('Decryption error:', error);
      return null;
    }
  }
  
  // Hash function for creating checksums
  async hashString(str) {
    const encoder = new TextEncoder();
    const data = encoder.encode(str);
    const hashBuffer = await crypto.subtle.digest('SHA-256', data);
    const hashArray = Array.from(new Uint8Array(hashBuffer));
    return hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
  }
  
  // Validate API key format (basic validation)
  validateApiKey(key, service) {
    if (!key) return true; // Allow empty keys
    
    switch (service) {
      case 'gemini':
        // Gemini API keys typically start with 'AIza' and are ~39 characters
        return /^AIza[A-Za-z0-9_-]{35,45}$/.test(key);
      case 'openai':
        // OpenAI API keys typically start with 'sk-' and are ~51 characters
        return /^sk-[A-Za-z0-9]{48}$/.test(key);
      default:
        return key.length > 10; // Basic length check
    }
  }
}

// For production use, consider using the Web Crypto API for stronger encryption:
// https://developer.mozilla.org/en-US/docs/Web/API/SubtleCrypto

// Export for use in other modules
if (typeof module !== 'undefined' && module.exports) {
  module.exports = { ApiKeyEncryption };
}