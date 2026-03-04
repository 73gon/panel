
# OpenPanel Improvement Roadmap

This document outlines the development roadmap for **OpenPanel**, covering architectural fixes, usability improvements, reader enhancements, and infrastructure upgrades.

---

# Phase 1 — Foundation & Fixes

These tasks should be completed first because they affect the core structure of the project.

## 1. Full Rename: `read/panel` → `openpanel`

Standardize the project name across the entire codebase.

### Project Structure
- Rename workspace folders:
  - `read-server` → `openpanel-server`
  - `read-ui` → `openpanel-ui`
- Rename root folder:
  - `read` → `openpanel`

### Package Names
- `panel-ui` → `openpanel-ui`

### Docker
- Docker image:
  - `ghcr.io/73gon/panel` → `ghcr.io/73gon/openpanel`

### Scripts
- Rename updater scripts:
  - `panel-updater.*` → `openpanel-updater.*`

### Default Install Paths
- Linux:
  - `$HOME/panel` → `$HOME/openpanel`
- Windows:
  - `C:\panel` → `C:\openpanel`

### Zustand Persist Store
- `read-app-store` → `openpanel-store`

### Misc Updates
- API comment updates:
  - `"Read server"` → `"OpenPanel server"`

### Manual Tasks
- Rename GitHub repository to `openpanel`

---

## 2. Fix Update Button

The current **trigger-file mechanism** is unreliable.

### New System

Replace it with a **progress-aware update system**.

Backend responsibilities:

1. Pull new Docker image
2. Write update status to database or status file
3. Expose update progress endpoint

Frontend responsibilities:

- Poll backend update status
- Display real-time update state

### UI Flow

Pulling image...
Restarting containers...
Cleaning old images...
Done

Display a **progress bar** in the admin UI.

---

## 3. Fix Scanner Transparency

Current scanning process lacks feedback.

### Improvements

Add **real-time scan progress updates**.

### Backend

Expose progress events via:

- WebSocket **or**
- Server Sent Events (SSE)

Events should include:

file_name  
files_scanned  
files_total  
percentage_complete

### Frontend

Show:

- Progress bar
- Current file being scanned
- Scan statistics

Replace the current **polling-only** approach.

---

## 4. Editable Library Paths

Currently libraries cannot change paths without deletion.

### New Feature

Add endpoint:

PUT /libraries/:id/path

### Behavior

- Update root path of library
- Preserve:
  - series
  - books
  - metadata
  - reading progress
- Trigger **automatic re-scan** after path change

---

# Phase 2 — Auth & Onboarding Overhaul

Simplify authentication and onboarding for self-hosted environments.

## 5. Admin = First Profile

Remove the separate admin password system.

### New Rules

- First created profile becomes **admin**
- Admin flag: `is_admin = true`
- Admin profile cannot be deleted

### Permissions

Admin can:

- Manage libraries
- Manage users
- Access settings
- View logs
- Trigger updates

### Constraints

- Admin role **cannot be transferred**
- Username **can be changed**

---

## 6. Profile-Based Authentication

Remove guest/device-based mode.

### Login Flow

1. User enters:
   - name
   - password

2. Server creates long-lived session token

3. On return visits:
   - session auto-authenticates user

4. If session expires (e.g. 1 year):
   - user logs in again

### Privacy Design

- Users never see other usernames
- No profile selection screen
- No shared device profiles

### Storage Changes

Remove client-side progress tracking.

Delete:

Zustand recentReads  
device-based progress

All progress becomes **server-side per profile**.

---

## 7. Onboarding Wizard

When the database is empty, start a guided setup.

### Steps

1. Create admin account
2. Add first library path
3. Run initial scan
4. Finish setup

### UX Goals

- Simple
- Guided
- Clear progress feedback

Final step lands on **Home Page**.

---

# Phase 3 — Reader Improvements

Enhance the reading experience.

## 8. RTL Reading Support

Add **reading direction preferences**.

### Options

- LTR (Western comics)
- RTL (Manga)

### Behavior Changes

In single-page mode:

- Swap left/right tap zones
- Reverse arrow key navigation

Preference can be:

- per-series
- per-profile

---

## 9. Double-Page Spread Mode

Add two-page layout.

### Behavior

- Display two pages side-by-side
- Respect RTL/LTR ordering
- Detect wide pages automatically

Example:

[Page 10] [Page 11]

Wide cover pages display alone.

---

## 10. Fit Modes

Add display scaling modes.

Options:

- Fit to width
- Fit to height
- Fit to screen
- Original size

Preference stored **per-profile server-side**.

---

## 11. Page Bookmarking

Allow bookmarking pages inside books.

### Features

Users can:

- Bookmark pages
- View bookmark list
- Jump directly to bookmarked page

Bookmarks accessible from:

- reader toolbar
- series page

---

## 12. Chapter Detection

Detect chapters inside CBZ volumes.

### Detection Methods

Analyze:

- filename patterns
- numbering patterns
- directory structure

Books gain metadata:

has_chapters: true

---

## 13. Volume / Chapter Toggle

Series page toggle:

Volumes | Chapters

Chapter view flattens volumes into individual chapters.

---

## 14. Table of Contents Sidebar

Desktop-only feature.

### Behavior

- Appears when chapters exist
- Slide-in panel
- Hidden on mobile

Never overlaps reading area.

---

# Phase 4 — Discovery & Home Page

Improve content discovery.

## 15. Customizable Home Sections

Sections include:

- Continue Reading
- Recently Added
- Recently Updated
- By Genre
- Favorites

Admin defines defaults.

Each profile can toggle sections individually.

---

## 16. Filter & Sort

Library filtering options:

Filters:

- genre
- year
- status
- score

Sorting:

- name
- year
- score
- recently added
- recently read

Powered by **AniList metadata**.

---

## 17. Collections / Custom Shelves

Users can create collections.

Example:

Favorites  
Read Later  
Top Manga

Collections appear as:

- home page sections
- library tabs

---

# Phase 5 — Performance & PWA

Improve speed and installability.

## 18. Progressive Web App (PWA)

Add installable app support.

Use:

vite-plugin-pwa  
Workbox

### Features

- Service worker
- Offline caching
- Pre-cached app shell
- Install prompt

Allows users to **install OpenPanel like an app**.

---

## 19. Performance Audit

Optimize frontend bundle.

Tasks:

- Remove duplicate font loading
- Add Docker HEALTHCHECK
- Add route error boundaries
- Optimize bundle chunks
- Enable AVIF image support where possible

---

# Phase 6 — DevOps & Reliability

Improve operational tooling.

## 20. Admin Logs Panel

Add logs viewer in admin UI.

Logs include:

- scan events
- errors
- update attempts

Backend stores logs in:

- ring buffer
- or SQLite table

Logs can be filtered by:

info  
warn  
error

---

## 21. Database Backup

Add automated SQLite backups.

### Features

- Scheduled backups
- Stored in `data/backups/`
- Configurable retention
- Manual backup trigger in admin UI

---

## 22. Security Hardening

Add:

- rate limiting on auth endpoints
- security headers (CSP, X-Frame-Options)
- fix CORS dev port mismatch

---

## 23. README Overhaul

Rewrite README with:

- features
- screenshots
- installation
- configuration
- development setup

Add badges:

- Docker pulls
- version
- license

---

## 24. Showcase Website

Create a public website.

Possible stack:

- Astro
- Next.js
- GitHub Pages

Sections:

- landing page
- feature overview
- screenshots
- documentation
- changelog
