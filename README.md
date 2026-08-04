# Arrow Drift : Puzzle Game

## About this project

Arrow Drift is a Flutter mobile puzzle game. The player clears arrows from a board. An arrow can move only if its path is free. The app has a campaign of **1000 levels**, a **daily challenge**, **hints**, **lives**, and **ads** (banner, interstitial, rewarded). Progress and settings are saved on the device with SharedPreferences. The app is published on the Google Play Store.

## Tech stack (simple)

- **Flutter / Dart** — UI and game logic  
- **Riverpod** — app state  
- **GoRouter** — navigation  
- **SharedPreferences** — save level progress, streak, settings  
- **Google Mobile Ads** — ads  
- **Custom level generator** — builds solvable nested arrow puzzles by level number  

---

## Interview-style questions (you can prepare these)

**1. What is this app?**  
It is a puzzle game where you clear arrows in the right order. Campaign has 1000 levels, plus daily puzzles and ads for extra hints/lives.

**2. How do levels work?**  
Levels are not all handmade files. A generator creates a solvable board from the level number, with different difficulty bands (Easy → Grandmaster).

**3. How do you keep the board full but not too hard early on?**  
Arrow count follows the level band. Path length and fill settings ramp up after Easy so later levels look denser and harder.

**4. How is progress saved?**  
With SharedPreferences — current level, daily clears, streak, nickname, avatar, settings.

**5. How does the daily streak work?**  
Snapchat-style: countdown shows until midnight when today is still pending. Clear today → timer hides. Miss a day → streak resets.

**6. How are ads used?**  
Interstitial after every 4 campaign clears; rewarded ads for extra hint or life; banners on some screens.

**7. Name one hard bug you fixed.**  
Example: after a rewarded hint ad, the app gave two hints (board highlight + counter). Fixed so one ad adds one hint to the counter only; highlight on next tap.

**8. Why Riverpod?**  
To keep game state, progress, and settings clean and testable across screens.

**9. How do you ship to Play Store?**  
Release AAB signed with upload keystore (`key.properties` + `.jks`), bump version code, upload in Play Console.

**10. What would you improve next?**  
Real AdMob IDs, more analytics, push for streak reminders, smaller APK with minify.

---

## Run locally

```bash
flutter pub get
flutter run
```

Release Android bundle:

```bash
flutter build appbundle --release
```

---

## Short summary (4–5 lines for interviews)

Arrow Drift is a Flutter puzzle game with 1000 campaign levels and a daily challenge. Levels are generated in code so they stay solvable and get harder over time. Players use hints and lives; ads give extras when they run out. Progress and a midnight-based streak are stored on the device. The app uses Riverpod, GoRouter, and Google Mobile Ads, and is live on the Play Store.
