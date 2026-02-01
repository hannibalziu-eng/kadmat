# 🎬 قصتك لفيديو | Story to Video AI Generator

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/version-1.0.0-blue)]()
[![Status](https://img.shields.io/badge/status-Production%20Ready-brightgreen)]()

🔲 **أداة مجانية 100% | بدون رسوم إضافية | جودة احترافية**

## 🌟 ما هذه الأداة؟

الأداة تحول أي قصة، مانجا، مقالة أو نص إلى فيديو ترفيهي احترافي باستخدام الذكاء الاصطناعي المجاني.

### ✨ المميزات

- ✅ **تحليل ذكي** للقصا باستخراج المشاهد الرئيسية
- 🎨 **توليد صور AI** بأساليب متعددة (ربياليستي، أنمي، كرتون)
- 🎙️ **تعليق صوتي احترافي** بأصوات طبيعية متعددة
- 🎬 **فيديو نهائي** بجودة مثالية مع موسيقى ثابتة
- 🔰 **لا ترطيب** - بدون تكاليف أو اشتراكات
- 🎯 **واجهة ثرية** للمبتدئين والمحترفين

---

## 🚀 البداية السريعة

### 1️⃣ فتح الأداة

بسيط جداً - افتح ملف `story_to_video_ai.html` بأي مستعرب\n
```bash
open story_to_video_ai.html
```

### 2️⃣ أدراج القصة

1. **اللصق نصالقصة أو المقالة** (على الأقل 100 كلمة)
2. **اختر نوع المحتوى** (قصة، مانجا، مقالة، إلخ.)
3. **اضغط \"تحليل القصة بـ AI\"** وانتظر 2-3 ثواني

### 3️⃣ توليد الصور والصوت

1. **اختر عدد الصور** (3-5 موصى به)
2. **اختر الأسلوب البصري** (أنمي، واقعي، إلخ.)
3. **اضغط \"توليد الصور\"** وانتظر بعلماته التحميل
4. **أدخل التعليق الصوتي** واختر اللغة والسرعة
5. **اجل للفيديو النهائي** مع موسيقى وجودة مرغوبة

### 4️⃣ تحميل النتيجة

```javascript
// بعد زر \"إنشاء الفيديو\"، سيظهر زر \"تحميل\" لتحميل MP4
story_video.mp4 // حجم: 50-200 MB
```

---

## 📚 الجماع المستخدمة

### Google Cloud Text-to-Speech
- **اللاستخدام:** تعليق الصوتي الاحترافي
- **الحد المجاني:** 1،000،000 حرف/شهر
- **الرابط:** https://cloud.google.com/text-to-speech
- **اللغات:** عربي، إنجليزي، فرنسي، ، و +130 لغة أخرى
- **الأصوات:** 50+ صوت طبيعي

### Hugging Face Inference API
- **الاستخدام:** توليد الصور عالية الجودة
- **النماذج:** Stable Diffusion XL، DALL-E، Anime
- **الحد المجاني:** رابط فاي الطبقة مجاناً
- **الرابط:** https://huggingface.co

### AI Horde (100% Free)
- **الاستخدام:** توليد الصور مايان\nحددمجاني**بالكامل
- **لا يحتاج API Key:** استخدم `apikey: 0000000000`
- **الحد المجاني:** محدود بالفق فقط
- **الرابط:** https://aihorde.net

### LTX Studio
- **الاستخدام:** تحويل الصور لفيديو
- **الحد المجاني:** رابط في الطبقة مجاناً
- **الرابط:** https://ltx.studio

---

## 🔢 مرحال العمل المفصلة

### المرحلة 1: تحليل القصة

```javascript
// هذا ما يحدث:
• تقسيم القصة إلى مشاهد
• استخراج الأحداث الرئيسية
• نمذجة المحاور البصرية
• اقتراح الأسلوب البصري
• الحساب الزمني
```

### المرحلة 2: توليد الصور

**الأساليب المتاحة:**
- 📸 **واقعي** - صور فوتوغرافية يققيمية (رسالة، رومانسية)
- 🌸 **أنمي** - رسوم مأنخة (ألعاب ربوطابه تخيارية)
- 🎨 **كرتون** - رسوم بسيطة ومرحة (للأطفال)
- 🎬 **3D** - ثلاثية الأبعاد مع إضاءة سينمائية
- 🖼ufe0f **رسم زيتي** - أسلوب خاصانا كلاسيكي
- 💧 **ألوان مائية** - رمايق عازلة بلون يظلل بهما
- 💭 **كوميك** - أسلوب قصص مصورة جريئة

### المرحلة 3: الطبع الصوتي

```javascript
// الملخص الأول من القصة يتحول إلى:
• تعليق صوتي احترافي
• باختيارك اللغة والصوت
• تخصيص السرعة
```

**الأصوات المتاحة:**

| اللغة | الذكر | الأنثى |
|--------|--------|--------|
| **عربي** | ar-SA-Standard-A | ar-SA-Standard-C |
| **إنجليزي** | en-US-Standard-A | en-US-Standard-C |
| **محسّن** | en-US-Neural2-A | en-US-Neural2-C |

### المرحلة 4: الفيديو النهائي

```javascript
// الدمج:
• الصور بلوقت متساوية
• الطبع الصوتي فوق الصور
• موسيقى خلفية للعاطفة
• تحريكات انتقال سالسة
• الجودة المطلوبة (720p، 1080p، 4k)
```

**موسيقى متاحة:**
- 🎼 🎫🎬b **درامي** - للروايات الدرامية
- 🎬 **سينمائي** - للأفلام الاحترافية
- 🗻 **مغامرة** - للقصص المليئة بأحداث
- 🌊 **هادئة** - للقصا الرومانسية
- ⚔️ **ملحمية** - للقصا الخيالية

---

## 📚 الملفات

```
📁 لمشروع
├── 🎬 story_to_video_ai.html          # الأداة الرئيسية (الواجهة)
├── 🔧 story-to-video-api.js           # أكواد JavaScript الكاملة
├── 📚 API_INTEGRATION_GUIDE.md       # دليل التكامل الفني
├── 📄 README.md                     # هذا الملف
└── 🔐 .env.example                  # ما ونب ما لAPI الطالب
```

---

## 🔐 الحصول على API Keys

### Google Cloud Text-to-Speech

1. اذهب إلى [Google Cloud Console](https://console.cloud.google.com)
2. أنشئ مشروع جديد
3. فعل **Text-to-Speech API**
4. اذهب إلا **Credentials** وأنشئ API Key
5. الصق المفتاح في `.env`

```env
GOOGLE_TTS_KEY=your-api-key-here
```

### Hugging Face Token

1. اذهب إلا [Hugging Face](https://huggingface.co)
2. الدخول أو التسجيل
3. اذهب إلا **Settings** > **Access Tokens**
4. انسخ الرمز

```env
HUGGING_FACE_TOKEN=hf_xxxxxxxxxxxxx
```

### AI Horde (بدون مفتاح!)

```env
# لا يحتاج مفتاح - استخدم:
AI_HORDE_KEY=0000000000
```

---

## 💯 أمثلة عملية

### مثال 1: قصة بسيطة

```javascript
const storyText = `
عاش رجل طيب كبير السن في زاوية نائية من المدينة.
طوال ربع قرن من زمانه مكثفاً يعالج الأمراض بعناية وصبر.
لكن للأسف لم يعرف الرحمة بنفسه لنفسه.
لذلك قرر أن يعالج نفسه بطريقة لم راها بعد.
`;

const options = {
    contentType: 'story',
    artStyle: 'realistic',
    imageCount: 4,
    voiceType: 'ar-SA-Standard-A',
    musicStyle: 'dramatic',
    videoQuality: '1080p'
};

const video = await storyToVideo(storyText, options);
downloadFile(video, 'my_story.mp4');
```

### مثال 2: مانجا بأسلوب أنمي

```javascript
const mangaText = `
بطل واره يشعر بمقول المسؤولية لرعاية أطفال القرية.
راقب أعدائه بعناية ومحبة.
استهل عيناه مد زمن طاويل، مما أسبح عبقرياً.
لكن عزيمته زاالت لم تتكسر.
`;

const options = {
    contentType: 'manga',
    artStyle: 'anime',
    imageCount: 5,
    voiceType: 'ar-SA-Standard-C', // الضوت النسوي
    musicStyle: 'epic',
    videoQuality: '1080p'
};

const video = await storyToVideo(mangaText, options);
downloadFile(video, 'manga_story.mp4');
```

---

## ⚡ نصائح وتريكس

### لتسريع العمل:

1. **استخدم 720p** بدل 1080p للمعاينة السريعة
2. **قلل عدد الصور** - 3 ال 4 كافي، لا تا 10
3. **استخدم ملخص** - ربع طول القصة فقط
4. **استخدم AI Horde** - مجاني بالكامل بدون API Key

### لتحسين الجودة:

1. **استخدم 1080p أو 4K** للنتيجة النهائية
2. **فصل الوصف** بدقة أكثر للصور
3. **استخدم الأصوات المحسّنة** (Neural)
4. **اختر موسيقى مرافقة** للأسلوب بمسا القصة

---

## 🐛 حل المشاكل

### المشكلة: يقول \"المفم غير موجود\" عند فتم البرنامج

**الحل:**
- عم المفر بعيييك على برنامج المستعرئات (Chrome، Firefox، Safari)
- عم فتمه مباشرة بفتح `file://` protocol

### المشكلة: API Key لا يعمل

**الحل:**
- التابع متابع المتفال برافع المستعرئات (F12)
- بيقل الخطأ وابحث عن الحل بموقع [Stack Overflow](https://stackoverflow.com)

### المشكلة: الفيديو طويل للغاية

**الحل:**
- استخدم 720p بدل 1080p
- قلل عدد الصور
- قلل سرعة مدة الانتقال بين الصور

---

## 📋 مراجع مفيدة

- [Google Cloud TTS Documentation](https://cloud.google.com/text-to-speech/docs)
- [Hugging Face API Docs](https://huggingface.co/docs/api-inference/)
- [AI Horde API](https://aihorde.net/api)
- [FFmpeg Documentation](https://ffmpeg.org/documentation.html)
- [Stability AI Guide](https://platform.stability.ai/docs/getting-started)

---

## 🌟 مساهمول

If you find this tool useful and want to contribute, here are some ways you can help:

1. **Report bugs** - التقرم عن الأخطاء والمشاكل
2. **Suggest features** - امقترح مميزات جديدة
3. **Improve documentation** - ساعد في تحسين الزوثيق
4. **Share** - بوزع الأداة مع من يمكنهم استفادة منها

---

## 📉 الرخصة

MIT License - استخدم الأداة بحرية بالكاملل

---

## 🗣️ التواصل

- **Email**: support@example.com
- **GitHub**: [@yourrepo](https://github.com)
- **Twitter**: [@youraccount](https://twitter.com)

---

**رو براهين وفسير مهاراتك بالفيديوهات! 🌟**

*آخر تحديث: يناير 2025 | الإصدار: 1.0.0*
