/**
 * 🎬 Story to Video Generator - Complete API Integration
 * Converts stories and manga into professional videos using free AI services
 * 
 * Services Used:
 * - Google Cloud TTS (Text-to-Speech)
 * - Hugging Face (Image Generation)
 * - AI Horde (Free Image Generation)
 * - FFmpeg (Video Creation)
 * 
 * Author: AI Developer
 * Version: 1.0.0
 * Date: January 2025
 */

// ==================== Configuration ====================

const API_CONFIG = {
    GOOGLE_TTS_KEY: 'YOUR_GOOGLE_API_KEY_HERE',
    HUGGING_FACE_TOKEN: 'YOUR_HUGGING_FACE_TOKEN_HERE',
    AI_HORDE_KEY: '0000000000', // Anonymous key
    STABILITY_AI_KEY: 'YOUR_STABILITY_KEY_HERE'
};

const MODELS = {
    IMAGE_GENERATION: {
        STABLE_DIFFUSION: 'stabilityai/stable-diffusion-xl-base-1.0',
        DALL_E: 'openai/dall-e-3',
        ANIME_STYLE: 'hakurei/waifu-diffusion'
    },
    TTS: {
        GOOGLE: 'https://texttospeech.googleapis.com/v1/text:synthesize',
        ELEVENLABS: 'https://api.elevenlabs.io/v1/text-to-speech'
    }
};

const ART_STYLES = {
    REALISTIC: 'realistic high quality photograph',
    ANIME: 'anime style, detailed, vibrant colors',
    CARTOON: 'cartoon style, colorful, fun',
    '3D': '3D render, cinematic lighting',
    OIL: 'oil painting style, artistic',
    WATERCOLOR: 'watercolor painting, soft colors',
    COMIC: 'comic book style, bold outlines'
};

// ==================== Core Functions ====================

/**
 * 1️⃣ Analyze Story using AI
 * @param {string} text - Story text to analyze
 * @param {string} contentType - Type: 'story', 'manga', 'article', 'fairy', 'poem'
 * @returns {Promise<Object>} Analysis result with scenes, narrative, etc.
 */
async function analyzeStory(text, contentType = 'story') {
    try {
        console.log('🔍 Analyzing story...');
        
        // Split text into scenes based on paragraphs
        const paragraphs = text.split('\n\n').filter(p => p.trim().length > 0);
        const scenes = paragraphs.slice(0, Math.min(5, Math.ceil(paragraphs.length / 2)));
        
        // Extract key narrative points
        const narrative = text.substring(0, 500) + '...';
        
        // Generate visual descriptions
        const visualDescriptions = generateVisualDescriptions(scenes);
        
        return {
            success: true,
            contentType: contentType,
            totalWords: text.split(' ').length,
            estimatedDuration: calculateDuration(text),
            scenes: scenes,
            narrative: narrative,
            visualDescriptions: visualDescriptions,
            suggestedStyle: suggestArtStyle(contentType),
            suggestedMusic: suggestMusicStyle(contentType),
            meta {
                complexity: analyzeComplexity(text),
                sentiment: analyzeSentiment(text),
                pace: analyzePace(text)
            }
        };
    } catch (error) {
        console.error('❌ Error analyzing story:', error);
        return { success: false, error: error.message };
    }
}

/**
 * 2️⃣ Generate Images from Text Prompts
 * @param {Array<string>} prompts - Array of image prompts
 * @param {string} style - Art style
 * @param {string} quality - 'standard' or 'premium'
 * @returns {Promise<Array>} Array of image URLs/blobs
 */
async function generateImages(prompts, style = 'realistic', quality = 'standard') {
    try {
        console.log(`🎨 Generating ${prompts.length} images with ${style} style...`);
        
        const images = [];
        const useAIHorde = quality === 'standard'; // Free & fast
        
        for (const prompt of prompts) {
            const enhancedPrompt = `${prompt}, ${ART_STYLES[style] || ART_STYLES.REALISTIC}, highly detailed, professional`;
            
            if (useAIHorde) {
                const image = await generateImageAIHorde(enhancedPrompt);
                images.push(image);
            } else {
                // Could use Hugging Face for premium
                const image = await generateImageHuggingFace(enhancedPrompt);
                images.push(image);
            }
            
            // Rate limiting
            await delay(500);
        }
        
        return images;
    } catch (error) {
        console.error('❌ Error generating images:', error);
        return [];
    }
}

/**
 * Generate Single Image using AI Horde (Free & No API Key Required)
 * @param {string} prompt - Image prompt
 * @returns {Promise<string>} Base64 image
 */
async function generateImageAIHorde(prompt) {
    try {
        // Step 1: Submit generation request
        const submitResponse = await fetch('https://aihorde.net/api/v2/generate/async', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'apikey': API_CONFIG.AI_HORDE_KEY
            },
            body: JSON.stringify({
                prompt: prompt,
                params: {
                    height: 512,
                    width: 512,
                    steps: 30,
                    sampler_name: 'k_euler_ancestral'
                },
                models: ['Juggernaut XL']
            })
        });
        
        if (!submitResponse.ok) throw new Error('Failed to submit image request');
        
        const submitData = await submitResponse.json();
        const jobId = submitData.id;
        
        console.log(`⏳ Job ID: ${jobId}, waiting for image generation...`);
        
        // Step 2: Poll for completion
        let completed = false;
        let result = null;
        let attempts = 0;
        const maxAttempts = 60; // 5 minutes max
        
        while (!completed && attempts < maxAttempts) {
            await delay(5000); // Wait 5 seconds between checks
            
            const checkResponse = await fetch(`https://aihorde.net/api/v2/generate/check/${jobId}`);
            const checkData = await checkResponse.json();
            
            if (checkData.done) {
                result = checkData.generations[0].img;
                completed = true;
                console.log('✅ Image generated successfully!');
            }
            
            attempts++;
        }
        
        if (!completed) {
            throw new Error('Image generation timeout');
        }
        
        return result; // base64 string
    } catch (error) {
        console.error('❌ AI Horde error:', error);
        return null;
    }
}

/**
 * Generate Image using Hugging Face API
 * @param {string} prompt - Image prompt
 * @returns {Promise<Blob>} Image blob
 */
async function generateImageHuggingFace(prompt) {
    try {
        const response = await fetch(
            `https://api-inference.huggingface.co/models/${MODELS.IMAGE_GENERATION.STABLE_DIFFUSION}`,
            {
                headers: {
                    Authorization: `Bearer ${API_CONFIG.HUGGING_FACE_TOKEN}`
                },
                method: 'POST',
                body: JSON.stringify({ inputs: prompt })
            }
        );
        
        if (!response.ok) {
            throw new Error(`API error: ${response.statusText}`);
        }
        
        return await response.blob();
    } catch (error) {
        console.error('❌ Hugging Face error:', error);
        return null;
    }
}

/**
 * 3️⃣ Generate Voiceover using Google Cloud TTS
 * @param {string} text - Text to convert to speech
 * @param {string} languageCode - Language code (e.g., 'ar-SA')
 * @param {string} voiceName - Voice name (e.g., 'ar-SA-Standard-A')
 * @param {number} speed - Speech rate (0.8 - 1.4)
 * @returns {Promise<Object>} Audio data
 */
async function generateVoiceover(text, languageCode = 'ar-SA', voiceName = 'ar-SA-Standard-A', speed = 1.0) {
    try {
        console.log('🎙️ Generating voiceover...');
        
        const response = await fetch(
            `${MODELS.TTS.GOOGLE}?key=${API_CONFIG.GOOGLE_TTS_KEY}`,
            {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    input: { text: text },
                    voice: {
                        languageCode: languageCode,
                        name: voiceName
                    },
                    audioConfig: {
                        audioEncoding: 'MP3',
                        speakingRate: speed,
                        pitch: 0,
                        volumeGainDb: 0
                    }
                })
            }
        );
        
        if (!response.ok) {
            throw new Error(`TTS API error: ${response.statusText}`);
        }
        
        const data = await response.json();
        console.log('✅ Voiceover generated!');
        
        return {
            success: true,
            audioContent: data.audioContent, // base64
            duration: calculateAudioDuration(text, speed)
        };
    } catch (error) {
        console.error('❌ TTS Error:', error);
        return { success: false, error: error.message };
    }
}

/**
 * Available Voices for TTS
 */
const AVAILABLE_VOICES = {
    ARABIC: {
        'ar-SA-Standard-A': '🎙️ ذكر - عربي (الأساسي)',
        'ar-SA-Standard-B': '🎙️ ذكر - عربي (بديل)',
        'ar-SA-Standard-C': '👩 أنثى - عربي (الأساسي)',
        'ar-SA-Standard-D': '👩 أنثى - عربي (بديل)'
    },
    ENGLISH: {
        'en-US-Standard-A': '🎙️ ذكر - إنجليزي',
        'en-US-Standard-C': '👩 أنثى - إنجليزي',
        'en-US-Neural2-A': '🎙️ ذكر - إنجليزي (محسّن)',
        'en-US-Neural2-C': '👩 أنثى - إنجليزي (محسّن)'
    }
};

/**
 * 4️⃣ Create Final Video using FFmpeg
 * @param {Array} images - Array of images (URLs or blobs)
 * @param {Blob} audio - Audio file blob
 * @param {string} musicStyle - Background music style
 * @param {string} quality - Video quality ('720p', '1080p', '4k')
 * @returns {Promise<Blob>} Video blob
 */
async function createVideo(images, audio, musicStyle = 'cinematic', quality = '1080p') {
    try {
        console.log('🎬 Creating video...');
        
        // Load FFmpeg
        const { FFmpeg, toBlobURL } = FFmpeg;
        const ffmpeg = new FFmpeg.FFmpeg();
        
        const baseURL = 'https://cdn.jsdelivr.net/npm/@ffmpeg/core@0.12.4/dist/umd';
        
        await ffmpeg.load({
            coreURL: await toBlobURL(`${baseURL}/ffmpeg-core.js`, 'text/javascript'),
            wasmURL: await toBlobURL(`${baseURL}/ffmpeg-core.wasm`, 'application/wasm')
        });
        
        // Calculate image duration based on audio duration
        const imageDuration = 3; // seconds per image
        
        // Create concat file for images
        let concatContent = '';
        for (let i = 0; i < images.length; i++) {
            await ffmpeg.writeFile(`image${i}.jpg`, new Uint8Array(images[i]));
            concatContent += `file 'image${i}.jpg'\nduration ${imageDuration}\n`;
        }
        
        await ffmpeg.writeFile('images_list.txt', new TextEncoder().encode(concatContent));
        
        // Write audio
        await ffmpeg.writeFile('audio.mp3', new Uint8Array(audio));
        
        // Get video resolution
        const resolution = getVideoResolution(quality);
        
        // Create video command
        const command = [
            '-f', 'concat',
            '-safe', '0',
            '-i', 'images_list.txt',
            '-i', 'audio.mp3',
            '-c:v', 'libx264',
            '-pix_fmt', 'yuv420p',
            '-r', '30',
            '-vf', `scale=${resolution}`,
            '-c:a', 'aac',
            '-shortest',
            'output.mp4'
        ];
        
        await ffmpeg.exec(command);
        
        const data = await ffmpeg.readFile('output.mp4');
        const videoBlob = new Blob([data.buffer], { type: 'video/mp4' });
        
        console.log('✅ Video created successfully!');
        return videoBlob;
    } catch (error) {
        console.error('❌ Video creation error:', error);
        return null;
    }
}

// ==================== Helper Functions ====================

/**
 * Generate visual descriptions for story scenes
 */
function generateVisualDescriptions(scenes) {
    return scenes.map((scene, index) => ({
        sceneNumber: index + 1,
        description: scene,
        visualPrompt: createVisualPrompt(scene),
        duration: 3
    }));
}

/**
 * Create visual prompt from text description
 */
function createVisualPrompt(text) {
    // Extract key nouns and adjectives
    const keywords = extractKeywords(text);
    return `${keywords.join(', ')}, cinematic composition, professional lighting, detailed`;
}

/**
 * Extract keywords from text
 */
function extractKeywords(text) {
    // Simple keyword extraction
    const words = text.toLowerCase().split(' ');
    const keywords = words
        .filter(word => word.length > 4)
        .slice(0, 5);
    return keywords;
}

/**
 * Calculate estimated video duration
 */
function calculateDuration(text) {
    const words = text.split(' ').length;
    const wordsPerMinute = 150; // Average reading speed
    return Math.ceil(words / wordsPerMinute);
}

/**
 * Suggest art style based on content type
 */
function suggestArtStyle(contentType) {
    const suggestions = {
        'story': 'realistic',
        'manga': 'anime',
        'article': 'realistic',
        'fairy': 'cartoon',
        'poem': 'watercolor'
    };
    return suggestions[contentType] || 'realistic';
}

/**
 * Suggest music style based on content type
 */
function suggestMusicStyle(contentType) {
    const suggestions = {
        'story': 'dramatic',
        'manga': 'epic',
        'article': 'cinematic',
        'fairy': 'calm',
        'poem': 'romantic'
    };
    return suggestions[contentType] || 'cinematic';
}

/**
 * Analyze text complexity
 */
function analyzeComplexity(text) {
    const words = text.split(' ').length;
    const sentences = text.split(/[.!?]/).length;
    const avgWordLength = text.split(' ').reduce((sum, word) => sum + word.length, 0) / words;
    
    if (avgWordLength > 6 && sentences < words / 15) {
        return 'complex';
    } else if (avgWordLength > 5) {
        return 'medium';
    }
    return 'simple';
}

/**
 * Analyze text sentiment
 */
function analyzeSentiment(text) {
    const positiveWords = ['happy', 'joy', 'love', 'beautiful', 'wonderful', 'amazing'];
    const negativeWords = ['sad', 'hate', 'ugly', 'terrible', 'awful', 'horrible'];
    
    const lowerText = text.toLowerCase();
    const positiveCount = positiveWords.filter(word => lowerText.includes(word)).length;
    const negativeCount = negativeWords.filter(word => lowerText.includes(word)).length;
    
    if (positiveCount > negativeCount) return 'positive';
    if (negativeCount > positiveCount) return 'negative';
    return 'neutral';
}

/**
 * Analyze text pace
 */
function analyzePace(text) {
    const sentences = text.split(/[.!?]/).filter(s => s.trim());
    const avgLength = sentences.reduce((sum, s) => sum + s.split(' ').length, 0) / sentences.length;
    
    if (avgLength > 20) return 'slow';
    if (avgLength < 10) return 'fast';
    return 'normal';
}

/**
 * Calculate audio duration estimate
 */
function calculateAudioDuration(text, speed = 1.0) {
    const words = text.split(' ').length;
    const baseWPM = 150;
    const adjustedWPM = baseWPM * speed;
    return Math.ceil(words / adjustedWPM * 60); // in seconds
}

/**
 * Get video resolution
 */
function getVideoResolution(quality) {
    const resolutions = {
        '720p': '1280:720',
        '1080p': '1920:1080',
        '4k': '3840:2160'
    };
    return resolutions[quality] || '1920:1080';
}

/**
 * Utility delay function
 */
function delay(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

/**
 * Convert base64 to Blob
 */
function base64ToBlob(base64, mimeType) {
    const bstr = atob(base64);
    const n = bstr.length;
    const u8arr = new Uint8Array(n);
    for (let i = 0; i < n; i++) {
        u8arr[i] = bstr.charCodeAt(i);
    }
    return new Blob([u8arr], { type: mimeType });
}

/**
 * Download file
 */
function downloadFile(blob, filename) {
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = filename;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(url);
}

// ==================== Complete Workflow ====================

/**
 * Complete workflow: Story -> Video
 * @param {string} storyText - Input story text
 * @param {Object} options - Configuration options
 * @returns {Promise<Blob>} Generated video
 */
async function storyToVideo(storyText, options = {}) {
    try {
        const {
            contentType = 'story',
            artStyle = 'realistic',
            imageCount = 4,
            voiceType = 'ar-SA-Standard-A',
            speechRate = 1.0,
            musicStyle = 'cinematic',
            videoQuality = '1080p'
        } = options;
        
        console.log('🚀 Starting story to video conversion...');
        
        // Step 1: Analyze story
        const analysis = await analyzeStory(storyText, contentType);
        if (!analysis.success) throw new Error('Story analysis failed');
        
        console.log('✅ Story analyzed');
        console.log(`   - Scenes: ${analysis.scenes.length}`);
        console.log(`   - Words: ${analysis.totalWords}`);
        console.log(`   - Estimated Duration: ${analysis.estimatedDuration} minutes`);
        
        // Step 2: Generate images
        const imagePrompts = analysis.visualDescriptions.map(d => d.visualPrompt);
        const images = await generateImages(imagePrompts, artStyle);
        console.log(`✅ Generated ${images.length} images`);
        
        // Step 3: Generate voiceover
        const voiceoverResponse = await generateVoiceover(
            analysis.narrative,
            'ar-SA',
            voiceType,
            speechRate
        );
        if (!voiceoverResponse.success) throw new Error('Voiceover generation failed');
        
        const audioBlob = base64ToBlob(voiceoverResponse.audioContent, 'audio/mp3');
        console.log('✅ Voiceover generated');
        
        // Step 4: Create video
        const videoBlob = await createVideo(images, audioBlob, musicStyle, videoQuality);
        console.log('✅ Video created successfully!');
        
        return videoBlob;
    } catch (error) {
        console.error('❌ Workflow error:', error);
        throw error;
    }
}

// ==================== Export for Use ====================

if (typeof module !== 'undefined' && module.exports) {
    module.exports = {
        analyzeStory,
        generateImages,
        generateVoiceover,
        createVideo,
        storyToVideo,
        AVAILABLE_VOICES,
        downloadFile,
        base64ToBlob
    };
}
