# SharePoint Timesheet Bot

Automates filling, saving, submitting, and recalling weekly timesheets on SharePoint PWA using Python + Playwright.

## Origin Story

*As told by Fable.*

---

Every great tool is born from suffering. This one was born from a bike crash and a Friday afternoon.

It started innocently enough — Darren, a software engineer of considerable talent and questionable road sense, was cycling to work when the universe decided to remind him that gravity is non-negotiable. One collision later, he was at home with a bruised ego, a sore everything, and — crucially — a SharePoint timesheet due by end of day.

He opened the page. He stared at the grid. The grid stared back.

SharePoint PWA's timesheet interface is one of those user experiences that makes you wonder if it was designed by someone who had never used software before, or had used *too much* of it and grown hateful. Clicking. Waiting. Clicking again. The JSGrid updating one cell at a time with the enthusiasm of a wet sock. Forty-five minutes for what should have been a two-minute job.

Darren, laid up and irritable, made a decision.

He would not do this again.

What followed was three weekends of Playwright, a deep-dive into SharePoint's undocumented JSGrid internals (units: 1/1000th of a minute — yes, really), and the discovery that Microsoft's session persistence makes ordinary cookie storage look like child's play. But piece by piece, it came together. Login. Navigate. Fill. Verify. Submit. Every Friday at 9 AM, automatically, without a human in the loop.

The bot now runs without complaint on macOS, Linux, and Windows. It handles public holidays, multi-week backfills, submitting, recalling, and every other timesheet indignity the system can throw at it.

Darren healed. The timesheets filed themselves. The bike has since been serviced.

JUSTICE CRASSSSSHHHHHHHH

![One bike crash to finish the battle](docs/justice_crash.png)

---

## Features

- **Batch fill** — fill hours for one or many weeks in a single run
- **Public holiday awareness** — automatically skips Australian public holidays (configurable state)
- **Planned → Actual** — optionally copy server-side Planned hours as Actual
- **Clear Planned** — zero-out Planned hours after filling
- **Non-config task cleanup** — clears hours from tasks not listed in your config
- **Save & verify** — saves and checks the summary page to confirm hours persisted
- **Submit** — submits timesheets for approval after filling
- **Recall** — recalls submitted/approved timesheets so they can be re-edited
- **Persistent SSO** — Microsoft login is saved across runs (manual login only needed once)
- **Scheduled runs** — macOS LaunchAgent, Linux systemd timer, or Windows Task Scheduler runs the bot every Friday at 9 AM automatically

## Setup

### 1. Create a virtual environment

```bash
python3 -m venv .venv
source .venv/bin/activate   # macOS / Linux
# .venv\Scripts\activate    # Windows
```

### 2. Install dependencies

```bash
pip install -r requirements.txt
playwright install chromium
```

### 3. Configure environment

```bash
cp .env.example .env
```

Edit `.env` with your SharePoint URLs:

```dotenv
SHAREPOINT_BASE_URL=https://yourcompany.sharepoint.com
SHAREPOINT_TIMESHEET_URL=https://yourcompany.sharepoint.com/sites/YourPWA/_layouts/15/pwa/Timesheet/MyTSSummary.aspx
HEADLESS=false
```

### 4. First-time login

```bash
.venv/bin/python main.py login
```

A browser window opens. Log in with your Microsoft account (including MFA). The session is saved to `browser_state/profile/` and reused automatically on subsequent runs.

## Configuration

Edit `config.yaml` to define your projects and defaults:

```yaml
defaults:
  total_hours_per_day: 8
  region: "NSW"              # Australian state for public holidays
  work_days:
    - Monday
    - Tuesday
    - Wednesday
    - Thursday
    - Friday

projects:
  - name: "ST-333 Marketplace 2.0"
    default_hours_per_day: 8
    clear_planned: true

  # Copy Planned hours as Actual instead of a fixed value:
  # - name: "ST-456 Other Project"
  #   use_planned: true

browser:
  slow_mo: 100               # ms delay between actions
  timeout: 60000             # ms timeout for page loads
  user_data_dir: "browser_state/profile"
```

### Project options

| Key | Type | Description |
|---|---|---|
| `name` | `str` | Task name as it appears in the SharePoint grid (substring match) |
| `default_hours_per_day` | `float` | Fixed hours to fill per work day |
| `use_planned` | `bool` | Copy server Planned hours as Actual instead of a fixed value |
| `clear_planned` | `bool` | Zero-out Planned hours for this task after filling |

Tasks **not** listed in `projects` will have their Actual and Planned hours cleared automatically.

## Usage

> All commands below use `.venv/bin/python`. If your venv is activated, you can use `python` directly.

### Fill the current week (dry run)

```bash
.venv/bin/python scripts/test_fill_timesheet.py --dry-run
```

### Fill the current week and save

```bash
.venv/bin/python scripts/test_fill_timesheet.py
```

### Fill the current week, save, and submit

```bash
.venv/bin/python scripts/test_fill_timesheet.py --submit
```

### Fill a date range

Use `--from DDMMYYYY` and `--to DDMMYYYY` to fill multiple weeks:

```bash
# Fill and submit all weeks from 5 Jan to 8 Feb 2026
.venv/bin/python scripts/test_fill_timesheet.py \
  --from 05012026 --to 08022026 --submit
```

Omitting `--to` defaults to the current week.

### Recall submitted/approved timesheets

```bash
# Recall a single week
.venv/bin/python scripts/test_fill_timesheet.py \
  --recall --from 02022026 --to 02022026

# Recall multiple weeks
.venv/bin/python scripts/test_fill_timesheet.py \
  --recall --from 06072026 --to 13072026
```

After recalling, re-run with `--from` / `--to` and `--submit` to re-fill and resubmit.

### Keep the browser open after completion

Add `--no-close` to any command to keep the browser window open for inspection:

```bash
.venv/bin/python scripts/test_fill_timesheet.py --submit --no-close
```

### CLI entry point (main.py)

`main.py` provides a Click-based CLI for single-week operations:

```bash
.venv/bin/python main.py login      # Save Microsoft SSO session
.venv/bin/python main.py inspect    # Open browser for manual inspection
.venv/bin/python main.py fill       # Fill current week and save
.venv/bin/python main.py fill --dry-run
.venv/bin/python main.py fill --submit
.venv/bin/python main.py fill --week 09/02/2026          # Fill a specific week
.venv/bin/python main.py fill --week 09/02/2026 --submit # Fill and submit a specific week
```

### Utility scripts

| Script | Purpose |
|---|---|
| `scripts/test_open_site.py` | Smoke test — opens SharePoint, checks page elements |
| `scripts/test_open_timesheet.py` | Opens the current week's timesheet for inspection |
| `scripts/test_fill_timesheet.py` | Main batch fill / submit / recall script |

## How It Works

1. Launches Chromium via Playwright using a **persistent browser profile**
2. Navigates to the SharePoint PWA Timesheet summary page
3. Handles Microsoft SSO (manual first time; auto-redirect on subsequent runs)
4. For each target week:
   - Opens the timesheet (creates it if status is "Not Yet Created")
   - Clears hours from tasks not in the config
   - Fills Actual hours via the JSGrid `UpdateProperties` API
   - Optionally clears Planned hours
   - Saves and verifies the total on the summary page
   - Optionally submits for approval

### Technical details

The SharePoint PWA grid (JSGrid) stores work-duration values in units of **1/1000th of a minute** — i.e. `hours × 60,000`. For example, 8h = `480,000`.

All writes use `grid.UpdateProperties()` with `SP.JsGrid.CreateValidatedPropertyUpdate()` to go through the grid's change-tracking pipeline. This ensures `IsDirty()` returns `true` and the Save button persists the changes server-side.

## Authentication & Session Persistence

The bot uses a **persistent Chromium profile** (`browser_state/profile/`) rather than cookie-only storage. This preserves the full browser state — cookies, localStorage, IndexedDB, and service workers — so Microsoft SSO sessions survive between runs.

| Scenario | What happens |
|---|---|
| First run | Browser opens; you log in manually (including MFA) |
| Subsequent runs | Saved profile auto-redirects past the login page |
| Session expired | Bot detects this and falls back to manual login prompt |
| Clear session | Delete the `browser_state/profile/` directory |

## Scheduled Execution

The bot runs automatically every Friday at 9 AM. Each platform uses its native scheduler — pick the section for your OS.

### macOS — LaunchAgent

```bash
# Install (via CLI)
python main.py schedule install

# Or directly via shell script
./scripts/install_launchagent.sh
./scripts/uninstall_launchagent.sh
```

The agent is loaded into `~/Library/LaunchAgents/` and survives reboots. It calls `scripts/run_timesheet.sh`, which kills stale Chromium locks, activates the venv, runs `--submit`, and writes timestamped logs to `logs/`.

```bash
# Monitor
python main.py schedule status
python main.py schedule logs
python main.py schedule logs -f     # follow
python main.py schedule logs -n 100 # last 100 lines
python main.py schedule run         # manual trigger
```

### Linux — systemd user timer

```bash
./scripts/install_systemd.sh
./scripts/uninstall_systemd.sh
```

Creates a `~/.config/systemd/user/sharepoint-timesheet-bot.{service,timer}` pair. The timer fires every Friday at 09:00 and uses `Persistent=true` so a missed run (machine was off) fires on next boot.

```bash
# Monitor
systemctl --user list-timers
systemctl --user start sharepoint-timesheet-bot.service  # manual trigger
journalctl --user -u sharepoint-timesheet-bot.service -f
```

### Windows — Task Scheduler

```powershell
# Install (run from repo root, PowerShell as your normal user)
.\scripts\install_task.ps1

# Uninstall
.\scripts\uninstall_task.ps1
```

Registers a Task Scheduler task named `SharePointTimesheetBot` that runs `scripts/run_timesheet.ps1` every Friday at 09:00. Uses `StartWhenAvailable` so a missed run fires at next login.

```powershell
# Monitor
Get-ScheduledTask -TaskName SharePointTimesheetBot
Start-ScheduledTask -TaskName SharePointTimesheetBot  # manual trigger
Get-Content logs\timesheet_*.log -Tail 50
```

## Project Structure

```
sharepoint_timesheet_bot/
├── bot/
│   ├── __init__.py          # Package init
│   ├── browser.py           # Playwright browser lifecycle & Microsoft SSO auth
│   ├── config.py            # YAML config & .env loader
│   ├── holidays.py          # Australian public holiday detection
│   ├── runner.py            # High-level orchestrator (used by main.py)
│   └── timesheet.py         # SharePoint page objects & JSGrid interactions
├── docs/
│   └── justice_crash.png    # Origin story illustration
├── scripts/
│   ├── run_timesheet.sh         # Wrapper for macOS/Linux scheduled runs
│   ├── run_timesheet.ps1        # Wrapper for Windows scheduled runs
│   ├── install_launchagent.sh   # Install macOS LaunchAgent
│   ├── uninstall_launchagent.sh # Uninstall macOS LaunchAgent
│   ├── install_systemd.sh       # Install Linux systemd timer
│   ├── uninstall_systemd.sh     # Uninstall Linux systemd timer
│   ├── install_task.ps1         # Install Windows Task Scheduler task
│   ├── uninstall_task.ps1       # Uninstall Windows Task Scheduler task
│   ├── test_open_site.py        # Smoke test — login & page element checks
│   ├── test_open_timesheet.py   # Open current week's timesheet
│   └── test_fill_timesheet.py   # Batch fill / submit / recall
├── browser_state/
│   └── profile/             # Persistent Chromium profile (gitignored)
├── logs/                    # Run logs (gitignored)
├── com.darren.timesheet-bot.plist  # macOS LaunchAgent config
├── .env                     # SharePoint URLs & runtime flags (gitignored)
├── .env.example             # Template for .env
├── .gitattributes
├── .gitignore
├── config.yaml              # Project & hours configuration
├── main.py                  # Click CLI entry point
├── pyproject.toml           # Project metadata & commitizen config
├── requirements.txt         # Python dependencies
├── CHANGELOG.md
└── README.md
```

## Security

- **Never commit** your `.env` file or `browser_state/` directory — both are in `.gitignore`.
- The persistent browser profile contains your full authenticated session. Treat it like a password.
