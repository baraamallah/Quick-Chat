// AI Service Integration
class AIService {
  constructor() {
    this.geminiApiKey = null;
    this.openaiApiKey = null;
    this.geminiApiAddress = null;
    this.openaiApiAddress = null;
    this.currentUser = null;
    this.encryption = new (typeof ApiKeyEncryption !== 'undefined' ? ApiKeyEncryption : class { 
      simpleDecrypt(key) { return key; } 
    })();
  }
  
  // Set user and their API keys
  async setUser(user) {
    this.currentUser = user;
    await this.loadApiKeys();
  }
  
  // Load API keys from user profile
  async loadApiKeys() {
    if (!this.currentUser) return;
    
    try {
      const { data, error } = await supabaseClient
        .from('users')
        .select('gemini_api_key, openai_api_key, gemini_api_address, openai_api_address')
        .eq('id', this.currentUser.id)
        .single();
        
      if (error) throw error;
      
      // Decrypt API keys if encryption is available
      this.geminiApiKey = this.encryption.simpleDecrypt(data.gemini_api_key);
      this.openaiApiKey = this.encryption.simpleDecrypt(data.openai_api_key);
      this.geminiApiAddress = data.gemini_api_address;
      this.openaiApiAddress = data.openai_api_address;
    } catch (error) {
      console.error('Error loading API keys:', error);
    }
  }
  
  // Save API keys to user profile
  async saveApiKeys(geminiKey = null, openaiKey = null, geminiAddress = null, openaiAddress = null) {
    if (!this.currentUser) return;
    
    try {
      // Encrypt API keys before storing (if encryption is available)
      const encryptedGeminiKey = this.encryption.simpleDecrypt(geminiKey) ? geminiKey : this.encryption.simpleEncrypt(geminiKey);
      const encryptedOpenaiKey = this.encryption.simpleDecrypt(openaiKey) ? openaiKey : this.encryption.simpleEncrypt(openaiKey);
      
      const { error } = await supabaseClient
        .rpc('update_user_api_keys', {
          user_id_in: this.currentUser.id,
          gemini_key_in: encryptedGeminiKey,
          openai_key_in: encryptedOpenaiKey,
          gemini_address_in: geminiAddress,
          openai_address_in: openaiAddress
        });
        
      if (error) throw error;
      
      // Update local copies
      this.geminiApiKey = geminiKey;
      this.openaiApiKey = openaiKey;
      this.geminiApiAddress = geminiAddress;
      this.openaiApiAddress = openaiAddress;
      
      return { success: true };
    } catch (error) {
      console.error('Error saving API keys:', error);
      return { success: false, error: error.message };
    }
  }
  
  // Send message to Gemini
  async sendToGemini(message, history = []) {
    if (!this.geminiApiKey) {
      throw new Error('Gemini API key not configured');
    }
    
    try {
      const apiAddress = this.geminiApiAddress || 'https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent';
      const response = await fetch(`${apiAddress}?key=${this.geminiApiKey}`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          contents: [{
            parts: [{
              text: message
            }]
          }]
        })
      });
      
      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.error?.message || 'Failed to get response from Gemini');
      }
      
      const data = await response.json();
      const reply = data.candidates?.[0]?.content?.parts?.[0]?.text || "Sorry, I couldn't generate a response.";
      
      return {
        success: true,
        reply: reply,
        model: 'Gemini'
      };
    } catch (error) {
      console.error('Gemini API error:', error);
      return {
        success: false,
        error: error.message,
        model: 'Gemini'
      };
    }
  }
  
  // Send message to ChatGPT
  async sendToChatGPT(message, history = []) {
    if (!this.openaiApiKey) {
      throw new Error('OpenAI API key not configured');
    }
    
    try {
      // Format messages for ChatGPT
      const messages = [...history, { role: 'user', content: message }];
      const apiAddress = this.openaiApiAddress || 'https://api.openai.com/v1/chat/completions';
      
      const response = await fetch(apiAddress, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${this.openaiApiKey}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          model: 'gpt-3.5-turbo',
          messages: messages,
          temperature: 0.7
        })
      });
      
      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.error?.message || 'Failed to get response from ChatGPT');
      }
      
      const data = await response.json();
      const reply = data.choices?.[0]?.message?.content?.trim() || "Sorry, I couldn't generate a response.";
      
      return {
        success: true,
        reply: reply,
        model: 'ChatGPT'
      };
    } catch (error) {
      console.error('ChatGPT API error:', error);
      return {
        success: false,
        error: error.message,
        model: 'ChatGPT'
      };
    }
  }
  
  // Generic AI message handler
  async sendMessage(message, aiService = 'auto', history = []) {
    // If auto, choose based on available keys
    if (aiService === 'auto') {
      if (this.geminiApiKey) {
        aiService = 'gemini';
      } else if (this.openaiApiKey) {
        aiService = 'chatgpt';
      } else {
        throw new Error('No AI service configured. Please add an API key.');
      }
    }
    
    // Route to appropriate service
    switch (aiService) {
      case 'gemini':
        return await this.sendToGemini(message, history);
      case 'chatgpt':
        return await this.sendToChatGPT(message, history);
      default:
        throw new Error('Unsupported AI service');
    }
  }
  
  // Check if any AI services are configured
  isConfigured() {
    return !!(this.geminiApiKey || this.openaiApiKey);
  }
  
  // Get list of available services
  getAvailableServices() {
    const services = [];
    if (this.geminiApiKey) services.push('gemini');
    if (this.openaiApiKey) services.push('chatgpt');
    return services;
  }
}

// Initialize AI service
const aiService = new AIService();

// Export for use in other modules
if (typeof module !== 'undefined' && module.exports) {
  module.exports = { AIService, aiService };
}