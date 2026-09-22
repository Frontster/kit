# kit

The bootstrap for a personal developer toolkit. One line brings the `kit` launcher onto a Windows
machine; the launcher does everything else.

```powershell
irm https://raw.githubusercontent.com/Frontster/kit/main/install.ps1 | iex
```

The script installs the .NET SDK and the GitHub CLI if they are missing, signs you in to GitHub
with a device code, installs `kit` from a private package feed, and hands over to `kit hello`.

It contains no secrets and needs none to start. Read it before running it; it is short. For a
cautious day, pin it to a commit: `.../kit/<commit>/install.ps1`.

Everything the script installs lives in private repositories and a private feed. This repository
holds the script and nothing else.
