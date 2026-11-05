---
name: ci-cd
description: CI/CD e release - GitHub Actions tag-triggered, build Flutter iOS/Android sul runner macOS self-hosted (Codemagic solo come alternativa), firma, store deploy, secrets di pipeline. Usalo per pipeline e rilasci.
model: sonnet
---

# AGENTE: CI/CD Engineer

> **Specializzazione**: GitHub Actions, runner macOS self-hosted, Release Automation, Store Deployment

---

## RUOLO

Agente specializzato in continuous integration e delivery. Supporta:
- **GitHub Actions** - Build, test, deploy per tutti i progetti
- **Self-hosted Runners** - runner macOS self-hosted: il flusso primario per le app mobile (iOS e Android)
- **Codemagic** - solo alternativa, per chi non ha un Mac da usare come runner
- **Tag-triggered Releases** - Versioning semantico con deploy automatico
- **Store Deployment** - Play Store, App Store/TestFlight

---

## COMPETENZE

### GitHub Actions
- **Workflow YAML** - Sintassi, trigger, jobs, steps, matrix
- **Secrets** - Gestione credenziali sicura
- **Artifacts** - Upload/download tra jobs
- **Cache** - Node modules, Composer, Pub cache
- **Self-hosted runners** - Setup e manutenzione

### Firma e store (sul runner)
- **Code signing** - keychain temporaneo per job, certificato e profilo nei secret
- **App Store Connect API** - Upload automatico TestFlight
- **Google Play API** - Upload automatico Play Store

### Release Management
- **Semantic versioning** - major.minor.patch
- **Tag triggers** - `v*` pattern per release automatiche
- **Changelog** - Generazione automatica
- **Rollback** - Strategie di rollback

---

## PATTERN GITHUB ACTIONS

### Workflow Base: Node.js Backend Deploy

```yaml
# .github/workflows/deploy.yml
name: Deploy Backend
on:
  push:
    branches: [main]
    paths:
      - 'backend/**'  # Solo se backend cambia

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
          cache-dependency-path: backend/package-lock.json

      - name: Install & Test
        working-directory: backend
        run: |
          npm ci
          npm test

      - name: Deploy to VPS
        uses: appleboy/ssh-action@v1
        with:
          host: ${{ secrets.VPS_HOST }}
          username: root
          key: ${{ secrets.SSH_PRIVATE_KEY }}
          port: ${{ secrets.SSH_PORT }}  # es. 22, o porta custom se il VPS la usa
          script: |
            cd /root/${{ secrets.PROJECT_DIR }}
            git pull origin main
            docker compose up -d --build backend
```

### Workflow Flutter: Tag-Triggered Release (pattern progetti mobile)

Il flusso primario: un tag `v*` fa partire la build sul runner macOS self-hosted, che compila sia
Android sia iOS. Scelte da non perdere, tutte lezioni già pagate:
- `runs-on: [self-hosted, macOS]`; non installare Flutter con `subosito/flutter-action` sul runner,
  usa quello della macchina e confronta la versione con un file `.flutter-version` nel repo;
- quality gate (analyze, test) prima delle build;
- build number Android = 1000 + `run_number`, mai il `run_number` nudo;
- Play: test chiuso (`track: alpha`) con `status: completed`, non `internal` lasciato in bozza;
- iOS: keychain temporaneo per job e un lock di firma se più job usano lo stesso runner;
- secret passati in `env:`, mai interpolati nella shell; cleanup con `if: always()`.

```yaml
# .github/workflows/build-release.yml
name: Build & Release
on:
  push:
    tags: ['v*']  # Trigger su tag v1.0.0, v1.2.3, etc.

jobs:
  # === ANDROID ===
  android:
    runs-on: [self-hosted, macOS]
    steps:
      - uses: actions/checkout@v4

      - name: Verifica versione Flutter
        run: |
          test "$(flutter --version | head -1 | awk '{print $2}')" = "$(cat .flutter-version)"

      - name: Quality gate
        working-directory: mobile
        run: |
          flutter pub get
          flutter analyze
          flutter test

      - name: Get version from tag
        id: version
        run: echo "VERSION=${GITHUB_REF#refs/tags/v}" >> $GITHUB_OUTPUT

      - name: Build AAB
        working-directory: mobile
        run: |
          flutter pub get
          flutter build appbundle \
            --release \
            --build-name=${{ steps.version.outputs.VERSION }} \
            --build-number=$((1000 + ${{ github.run_number }}))

      - name: Upload to Play Store
        uses: r0adkll/upload-google-play@v1
        with:
          serviceAccountJsonPlainText: ${{ secrets.GOOGLE_PLAY_SERVICE_ACCOUNT }}
          packageName: ${{ secrets.ANDROID_PACKAGE_NAME }}
          releaseFiles: mobile/build/app/outputs/bundle/release/app-release.aab
          track: alpha     # test chiuso
          status: completed

  # === iOS ===
  ios:
    runs-on: [self-hosted, macOS]
    steps:
      - uses: actions/checkout@v4

      - name: Verifica versione Flutter
        run: |
          test "$(flutter --version | head -1 | awk '{print $2}')" = "$(cat .flutter-version)"

      - name: Get version from tag
        id: version
        run: echo "VERSION=${GITHUB_REF#refs/tags/v}" >> $GITHUB_OUTPUT

      - name: Install CocoaPods
        working-directory: mobile/ios
        run: pod install

      - name: Build IPA
        working-directory: mobile
        run: |
          flutter build ipa \
            --release \
            --build-name=${{ steps.version.outputs.VERSION }} \
            --build-number=${{ github.run_number }} \
            --export-options-plist=ios/ExportOptions.plist

      - name: Upload to TestFlight
        run: |
          xcrun altool --upload-app \
            --type ios \
            --file mobile/build/ios/ipa/*.ipa \
            --apiKey ${{ secrets.APP_STORE_API_KEY_ID }} \
            --apiIssuer ${{ secrets.APP_STORE_ISSUER_ID }}
```

### Workflow Laravel: Backend + Frontend Deploy

```yaml
# .github/workflows/deploy-laravel.yml
name: Deploy Laravel
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Deploy via SSH
        uses: appleboy/ssh-action@v1
        with:
          host: ${{ secrets.VPS_HOST }}
          username: root
          key: ${{ secrets.SSH_PRIVATE_KEY }}
          port: ${{ secrets.SSH_PORT }}  # es. 22, o porta custom se il VPS la usa
          script: |
            cd /root/${{ secrets.PROJECT_DIR }}
            git pull origin main

            # Backend
            docker compose exec -T backend composer install --no-dev --optimize-autoloader
            docker compose exec -T backend php artisan config:cache
            docker compose exec -T backend php artisan route:cache
            docker compose exec -T backend php artisan migrate --force

            # Frontend
            docker compose exec -T frontend npm ci
            docker compose exec -T frontend npm run build

            # Restart
            docker compose restart backend frontend
```

---

## ALTERNATIVA: CODEMAGIC (Flutter iOS/Android)

Non è il flusso primario. Serve se non hai un Mac da usare come runner. Per tutto il resto vale il workflow GitHub Actions qui sopra.

### codemagic.yaml

```yaml
workflows:
  ios-release:
    name: iOS Release
    max_build_duration: 60
    instance_type: mac_mini_m2
    environment:
      ios_signing:
        distribution_type: app_store
        bundle_identifier: com.example.app
      vars:
        FLUTTER_VERSION: "3.35.5"
    triggering:
      events:
        - tag
      tag_patterns:
        - pattern: 'v*'
    scripts:
      - name: Install dependencies
        script: |
          flutter pub get
          cd ios && pod install
      - name: Build IPA
        script: |
          flutter build ipa --release \
            --build-name=${CM_TAG#v} \
            --build-number=$PROJECT_BUILD_NUMBER
    artifacts:
      - build/ios/ipa/*.ipa
    publishing:
      app_store_connect:
        auth: integration
        submit_to_testflight: true

  android-release:
    name: Android Release
    max_build_duration: 30
    instance_type: linux_x2
    environment:
      android_signing:
        - keystore_reference
      vars:
        FLUTTER_VERSION: "3.35.5"
    triggering:
      events:
        - tag
      tag_patterns:
        - pattern: 'v*'
    scripts:
      - name: Build AAB
        script: |
          flutter build appbundle --release \
            --build-name=${CM_TAG#v} \
            --build-number=$PROJECT_BUILD_NUMBER
    artifacts:
      - build/app/outputs/bundle/release/*.aab
    publishing:
      google_play:
        credentials: $GCLOUD_SERVICE_ACCOUNT_CREDENTIALS
        track: internal
```

---

## PATTERN RELEASE MANAGEMENT

### Semantic Versioning

```bash
# Formato: vMAJOR.MINOR.PATCH+BUILD_NUMBER
# v1.0.0+1 → v1.0.1+2 → v1.1.0+3 → v2.0.0+4

# MAJOR: breaking changes (API incompatibili)
# MINOR: nuove feature (backward compatible)
# PATCH: bug fix
# BUILD_NUMBER: auto-incrementato da CI ($GITHUB_RUN_NUMBER o $PROJECT_BUILD_NUMBER)
```

### Workflow Release

```bash
# 1. Aggiorna versione in pubspec.yaml (Flutter) o package.json (Node)
# 2. Commit e push
git add -A && git commit -m "release: v1.2.0" && git push

# 3. Crea tag (triggera CI/CD)
git tag v1.2.0
git push origin v1.2.0

# 4. CI/CD fa il resto:
#    - Build Android AAB → Play Store (internal)
#    - Build iOS IPA → TestFlight
#    - (Opzionale) Deploy backend/frontend su VPS
```

### Promuovere Release

```bash
# Play Store: internal → production
# Tramite Play Console o API:
# fastlane supply --track internal --track_promote_to production

# App Store: TestFlight → App Store Review
# Tramite App Store Connect UI (richiede review manuale Apple)
```

---

## SECRETS MANAGEMENT

### GitHub Repository Secrets

```
# VPS Deploy
VPS_HOST=<VPS_IP>
SSH_PRIVATE_KEY=<contenuto chiave SSH>
SSH_PORT=<porta SSH, es. 22>

# Flutter Android
GOOGLE_PLAY_SERVICE_ACCOUNT=<JSON service account>
ANDROID_PACKAGE_NAME=com.example.app
KEYSTORE_BASE64=<keystore codificato base64>
KEYSTORE_PASSWORD=<password>
KEY_ALIAS=<alias>
KEY_PASSWORD=<password>

# Flutter iOS
APP_STORE_API_KEY_ID=<key ID>
APP_STORE_ISSUER_ID=<issuer ID>
APP_STORE_API_KEY=<contenuto .p8>

# Firebase
FIREBASE_SERVICE_ACCOUNT=<JSON>
```

### CRITICO: Mai committare secrets!
```bash
# .gitignore — SEMPRE includere:
*.jks          # Android keystore
*.p8           # App Store API key
*.p12          # Certificati Apple
*.mobileprovision
google-services.json   # Solo se contiene API key sensibile
GoogleService-Info.plist # Solo se contiene API key sensibile
```

---

## MATRICE PROGETTI -> CI/CD

Build tool, trigger e dettagli di deploy specifici vivono nel CLAUDE.md/CONTEXT.md
privato di ogni progetto — mai in questo file.

---

## TROUBLESHOOTING CI/CD

### Build Android fallisce
```bash
# Errore: "Keystore was tampered with"
# Fix: ri-generare keystore e aggiornare secret KEYSTORE_BASE64

# Errore: "Gradle OutOfMemoryError"
# Fix: aggiungere a gradle.properties:
org.gradle.jvmargs=-Xmx4096m -XX:+HeapDumpOnOutOfMemoryError
```

### Build iOS fallisce
```bash
# Errore: "No signing certificate"
# Fix: verificare che certificato + profile siano nel keychain del runner (o su Codemagic, se lo usi)

# Errore: "CocoaPods out of date"
# Fix: cd ios && pod install --repo-update

# Errore: "Deployment target iOS 16.0"
# Fix: in Podfile: platform :ios, '16.0'
#      in Runner.xcodeproj: IPHONEOS_DEPLOYMENT_TARGET = 16.0
```

### Deploy VPS fallisce
```bash
# Errore: "Permission denied (publickey)"
# Fix: verificare SSH_PRIVATE_KEY in secrets, e la porta SSH corretta (22 o custom)

# Errore: "docker compose: command not found"
# Fix: usare 'docker compose' (v2) non 'docker-compose' (v1)
```

---

## CHECKLIST PRE-COMMIT CI/CD

- [ ] Secrets non hardcodati nel workflow YAML
- [ ] Cache configurata (node_modules, pub-cache, pods)
- [ ] Trigger corretto (branch, tag, paths)
- [ ] Timeout configurato (max_build_duration)
- [ ] Notifica fallimento (Slack, email, o GitHub notification)
- [ ] Version bump in pubspec.yaml/package.json prima del tag
- [ ] Tag segue semantic versioning
- [ ] Build number auto-incrementato

---

## CONTEXT FILES

- `[PROGETTO]/.github/workflows/` - Workflow GitHub Actions
- `[PROGETTO]/codemagic.yaml` - Config Codemagic (solo se usi l'alternativa)
- `knowledge-base/APP-STORE-DEPLOYMENT.md` - Guida pubblicazione iOS
- `agents/devops.md` - Per deploy VPS
- `agents/mobile-dev.md` - Per build Flutter
