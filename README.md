
---

# AVM (Angular Version Manager) for Windows

**Switch between Angular versions instantly without dependency errors.**

`avm` is a lightweight, zero-dependency PowerShell wrapper that orchestrates **NVM (Node Version Manager)** and **Angular CLI** to keep your development environment strictly compatible.

No more:

* ❌ *"The Angular CLI requires a minimum Node version of..."*
* ❌ Manually uninstalling/reinstalling global `@angular/cli`.
* ❌ Guessing which Node LTS goes with Angular 14 vs 17.

## 🚀 Quick Install (One-Line)

Run this command in **PowerShell** to download and install AVM into your profile automatically:

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force; iwr -useb https://raw.githubusercontent.com/officialrakeshr/angular-version-manager-windows/refs/heads/main/instal_avm.ps1 | iex

```

---

## ⚡ Usage

Once installed, simply type `avm` followed by the Angular version you want.

### 1. Basic Switch

Switch to the latest stable version of a major Angular release.

```powershell
avm 17
# 🔄 Switches Node to v20 (LTS for Angular 17)
# ⬇️ Installs/Updates to the latest Angular CLI 17.x

```

```powershell
avm 16
# 🔄 Switches Node to v18 (LTS for Angular 16)
# ⬇️ Installs/Updates to the latest Angular CLI 16.x

```

### 2. Specific Version Switch

Need an exact patch version for a legacy project?

```powershell
avm 16.2.14
# 🔄 Switches to Node 18
# 🎯 Ensures exactly @angular/cli@16.2.14 is installed

```

---

## 🛠 Prerequisites

1. **Windows OS** (This is a PowerShell tool).
2. **[NVM for Windows](https://github.com/coreybutler/nvm-windows)** must be installed.
* *If you don't have it, download the [Setup.exe here](https://github.com/coreybutler/nvm-windows/releases).*



---

## ⚙️ How It Works

Angular versions are strictly tied to Node.js versions. `avm` automates this relationship using a compatibility matrix (updated through Angular 21+).

**When you run `avm 16`:**

1. **Lookup:** It knows Angular 16 works best with Node 18.
2. **NVM Switch:** It checks if you have Node 18 installed.
* *If yes:* runs `nvm use 18`.
* *If no:* runs `nvm install 18` then `nvm use 18`.


3. **CLI Check:** It checks your global `ng version`.
* *If match:* It does nothing (Instant switch).
* *If mismatch:* It runs `npm install -g @angular/cli@16`.



---

## 📅 Compatibility Matrix

AVM comes pre-configured with the official [Angular Version Compatibility](https://angular.dev/reference/versions) map:

| Angular Version | Node Version Managed by AVM |
| --- | --- |
| **v21** | Node 24 / 22 |
| **v20** | Node 22 |
| **v19** | Node 22 / 20 |
| **v18** | Node 20 |
| **v17** | Node 20 |
| **v16** | Node 18 |
| **v15** | Node 18 |
| **v14** | Node 16 |
| **v4 - v13** | Auto-mapped to legacy Node versions (14, 12, 10, etc.) |

---

## 🔧 Manual Installation

If you prefer not to use the one-line installer:

1. Download `install_avm.ps1` from this repository.
2. Right-click the file and select **Run with PowerShell**.
3. Follow the prompts (it will ask for Admin permission to set execution policy if needed).
4. Restart your terminal.

## ❤️ Contributing

Found a bug? Want to add Linux/Mac support? PRs are welcome!

1. Fork the repo.
2. Create your feature branch (`git checkout -b feature/AmazingFeature`).
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`).
4. Push to the branch (`git push origin feature/AmazingFeature`).
5. Open a Pull Request.

---

**License**
MIT

---
