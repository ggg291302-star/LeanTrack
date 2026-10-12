# Installing LeanTrack on your iPhone (Windows + Sideloadly)

"Sideloading" means installing an app from a file instead of from the App Store.
Sideloadly does the signing for you with your free Apple ID, which is Apple's way of saying "this person allowed this app".

---

## 1. One-time setup on your PC

1. **Sideloadly** (you already have it). Download it from **https://sideloadly.io** only.
2. **iTunes and iCloud from Apple's website, not the Microsoft Store.** Sideloadly needs these to talk to your iPhone.
   Run these in PowerShell, one at a time:
   ```powershell
   Get-AppxPackage AppleInc.iTunes | Remove-AppxPackage
   ```
   ```powershell
   winget install --id Apple.iTunes --source winget
   ```
   ```powershell
   winget install --id Apple.iCloud --source winget
   ```
   Restart the PC afterwards.

## 2. Get the app file (LeanTrack.ipa)

The easiest way: open **https://github.com/ggg291302-star/LeanTrack/releases/latest** and click **LeanTrack.ipa** under "Assets".
(Claude can also download it for you into the `dist` folder inside `LeanTrack`.)

## 3. Plug in and trust

1. Connect the iPhone to the PC with a USB cable and unlock the phone.
2. If the phone asks **"Trust This Computer?"**, tap **Trust** and enter your phone passcode.

## 4. Install with Sideloadly

1. Open **Sideloadly**. Your iPhone should appear in the "iDevice" box.
2. Drag **LeanTrack.ipa** onto the big IPA icon (or click it and pick the file).
3. In **Apple Account**, type your Apple ID email. Type it into Sideloadly only, never into a chat.
4. Click **Start**. Type your Apple ID password, and the 2-factor code if asked, into **Sideloadly's** windows.
5. Wait until the log at the bottom says **Done**.

> Leave Sideloadly's **Advanced Options → Bundle ID** alone. LeanTrack's ID is `com.ggg291302.leantrack`, and if it changes, your phone treats it as a new app with empty data.

## 5. First launch on the iPhone (one time)

1. **Turn on Developer Mode:** **Settings → Privacy & Security → Developer Mode** → on. The phone restarts. After the restart, tap **Turn On** and enter your passcode.
   (The Developer Mode switch only shows up after a sideloaded app has been installed.)
2. **Trust yourself as the developer:** **Settings → General → VPN & Device Management** → tap your Apple ID under "Developer App" → **Trust** → **Trust**.
3. Open **LeanTrack**. 🎉

## 6. The 7-day rule (important)

Apps installed with a **free** Apple ID stop opening after **7 days**. Your data is **not** lost, and the app just needs to be signed again.

**To refresh:** repeat **step 4** with the same `LeanTrack.ipa` (or a newer one). Sideloadly installs **over the top**, and your food log, weigh-ins and settings stay.

- ✅ Do: reinstall over the top any time, even after it has expired.
- ❌ **Never delete the LeanTrack app from the phone** before reinstalling. Deleting it erases its data.
- Tip: Sideloadly has an **auto-refresh** option. It re-signs over Wi-Fi when the PC and phone are on the same network and the PC is on.
- Make a **Backup** inside the app now and then (More → Backup & Restore) and save it to Files or iCloud Drive. If the app ever gets deleted, you can restore from it.

## 7. Free Apple ID limits

- At most **3 sideloaded apps** at the same time on one phone.
- At most **10 new app IDs per 7 days**. Reinstalling LeanTrack reuses its ID, so this rarely matters.

## 8. Optional extras (type keys only into the app, never into a chat)

- **Brand-name foods and barcodes:** nothing to set up. The owner's free USDA key is added to the app when GitHub builds it (from the repository secret `USDA_API_KEY`, never stored in the code).
- **AI photo estimates** are switched off for now (they'd need a paid Anthropic key). Food photos use the iPhone's own on-device recognition.

## Troubleshooting

| What you see | What to do |
|---|---|
| Sideloadly doesn't see the iPhone | Unlock the phone, tap **Trust**, try another cable or USB port, make sure iTunes is the Apple-website version |
| "Untrusted Developer" when opening the app | Step 5.2 (VPN & Device Management → Trust) |
| App opens and closes right away after a week | It expired: redo step 4 (don't delete the app first) |
| "Maximum number of apps" error | Remove another sideloaded app, or wait for its slot to free up |
| Anything else | Take a screenshot of the Sideloadly log and send it to Claude |
