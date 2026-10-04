# 📱 Study Pro Mobile - GitHub se APK Generate Krne Ki Complete Guide

Aapka pura mobile application setup ready hai! Isme Android ke **all permissions (Storage, All Files Access, Foreground Background Downloads, Internet)** already configured hain.

Aapko apne computer me Flutter ya Android Studio install krne ki bilkul zaroorat nahi hai. GitHub Actions cloud me 2 se 3 minute ke andar free me direct **`app-release.apk`** compile krke de dega.

---

## 🚀 Step 1: GitHub pe New Repository Bnao
1. [github.com](https://github.com) open kro aur login kro.
2. Top right corner me **`+`** icon pe click krke **"New repository"** select kro.
3. Repository ka naam do (jaise: `study-pro-mobile`).
4. Visibility ko **Private** ya **Public** jo chahe select krlo.
5. **"Create repository"** pe click kro.

---

## 📂 Step 2: Code GitHub pe Upload Kro

### Option A: Direct Web Upload (Bina Git Command ke - Sabse Aasan Tarika)
1. Apne naye repository page pe **"uploading an existing file"** link pe click kro.
2. `mobile_application` folder ke andar ki **saari files & folders** ko drag & drop krke upload kr do:
   - `.github/` folder
   - `android/` folder
   - `lib/` folder
   - `pubspec.yaml`
   - `.gitignore`
3. Bottom me **"Commit changes"** button daba do.

*(Note: Make sure `.github/workflows/build_apk.yml` file upload ho gayi ho, kyunki wahi APK banati hai).*

---

### Option B: Git Command Line Se (Fastest)
Apne terminal ya PowerShell me `mobile_application` folder me jaao aur ye commands chalao:
```bash
git init
git add .
git commit -m "Initial commit for Study Pro Android App"
git branch -M main
git remote add origin https://github.com/APNA_USERNAME/study-pro-mobile.git
git push -u origin main
```

---

## ⚡ Step 3: APK Build Hote Dekho (Automated Cloud Build)
1. Repository page par upar **"Actions"** tab pe click kro.
2. Waha aapko **"Build Study Pro Android APK"** ya **"Compile Release APK"** running dikhai dega (Yellow circle 🟡).
3. 2 se 3 minute wait kro. Jaise hi build complete hoga, Green checkmark (🟢) lag jayega!

---

## 📥 Step 4: APK Download Kaise Krna Hai
1. Uss green checkmark wale workflow run pe click kro (e.g. *"Compile Release APK"*).
2. Page ke bottom me scroll kro, waha **"Artifacts"** section hoga.
3. Waha **`Study_Pro_Release_APK`** naam ka file milega. Uspe click krte hi zip file download ho jayegi.
4. Zip ko extract kro, uske andar **`app-release.apk`** mil jayega!

---

## 📲 Step 5: Android Phone Me Install & Use Kro
1. **`app-release.apk`** apne phone me send kro (WhatsApp/Telegram/USB/Drive).
2. Install pe click kro. Agar *"Install from unknown sources"* maange to allow kr do.
3. App open krte hi app **All Files Access & Storage Permission** maangega, use **Allow** kr do.
4. **Login / Activation**:
   - Apne Cloudflare Admin Panel se ek license key generate kro.
   - Phone me user name aur license key daal ke **Activate** pe click kro.
   - Mobile app Cloudflare server se connect hoke license verify kr lega aur central headers auto-sync kr lega!
5. **Course Load & Download**:
   - Web se syllabus JSON file paste ya load kro.
   - Videos aur Notes select krke **Download Now** daba do.
   - Saari files aapke phone ke **`Download/Study_Pro/`** folder me direct save hongi!

---

### 🛡️ App Features & Permissions Included:
- **MANAGE_EXTERNAL_STORAGE**: Android 10, 11, 12, 13, 14 ke sabhi phones me direct memory access.
- **Background Downloader**: Screen lock hone par bhi downloads band nahi honge (`FOREGROUND_SERVICE` & `WAKE_LOCK`).
- **Cloudflare License System**: Phone HWID (`MOB-...`) ke sath locked, duration countdown, instant block support.
- **Central Headers Auto-Sync**: Admin panel par cookie update krte hi phone me bina app update kiye nayi cookies aa jayengi.
- **Offline DRM Stream Handling**: Widevine DRM keys auto-resolve and encrypted stream decryption.
