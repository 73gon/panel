import { createFileRoute, Link } from '@tanstack/react-router'
import { HugeiconsIcon } from '@hugeicons/react'
import {
  Book02Icon,
  Search01Icon,
  UserMultiple02Icon,
  CloudIcon,
  SmartPhone01Icon,
  ShieldKeyIcon,
  ArrowRight01Icon,
  Bookmark01Icon,
  GridViewIcon,
  PaintBrushIcon,
} from '@hugeicons/core-free-icons'

export const Route = createFileRoute('/')({ component: HomePage })

/* ------------------------------------------------------------------ */
/*  Animated logo — 5×5 dot matrix                                     */
/* ------------------------------------------------------------------ */
const LOGO_PATTERN = [
  [1, 1, 1, 0, 1],
  [0, 0, 0, 0, 0],
  [1, 1, 1, 1, 1],
  [0, 0, 0, 0, 0],
  [1, 1, 0, 1, 1],
]

function AnimatedLogo() {
  const dotR = 10
  const spacing = 24
  const pad = 12
  const viewSize = pad * 2 + spacing * 4

  return (
    <svg
      width={150}
      height={150}
      viewBox={`0 0 ${viewSize} ${viewSize}`}
      className="mx-auto mb-8"
      aria-label="OpenPanel logo"
    >
      {/* Transparent background */}
      <rect width={viewSize} height={viewSize} fill="transparent" />
      {LOGO_PATTERN.flatMap((row, r) =>
        row.map((vis, c) => (
          <circle
            key={`${r}-${c}`}
            cx={pad + c * spacing}
            cy={pad + r * spacing}
            r={dotR}
            className={vis ? 'logo-dot-visible' : 'logo-dot-hidden'}
            style={{ animationDelay: `${(r + c) * 0.12}s` }}
          />
        )),
      )}
    </svg>
  )
}

/* ------------------------------------------------------------------ */
/*  Hero grid cell flash — triangles at 4 corners, 3 cells each        */
/* ------------------------------------------------------------------ */
const gridCells = [
  // Top-left: row0-col1, row1-col0  → ▟ pointing top-left
  { x: 64, y: 0 },
  { x: 0, y: 64 },
  // Top-right: row0-col0, row1-col1  → ▙ pointing top-right
  { x: 1028, y: 0 },
  { x: 1092, y: 64 },
  // Bottom-right: row0-col1, row1-col0  → ▛ pointing bottom-right
  { x: 1092, y: 640 },
  { x: 1028, y: 704 },
  // Bottom-left: row0-col0, row1-col1  → ▜ pointing bottom-left
  { x: 0, y: 640 },
  { x: 64, y: 704 },
]

/* ------------------------------------------------------------------ */
/*  Features data                                                      */
/* ------------------------------------------------------------------ */
const features = [
  {
    icon: Book02Icon,
    title: 'Zero Extraction',
    description:
      'Pages stream directly from CBZ archives — no temp files, no disk thrashing.',
  },
  {
    icon: Search01Icon,
    title: 'Automatic Scanning',
    description:
      'Drop new CBZ files into your library folder. OpenPanel detects and indexes them automatically.',
  },
  {
    icon: PaintBrushIcon,
    title: 'Multiple Reading Modes',
    description:
      'Continuous scroll, single page, or double page spread. LTR and RTL. Fit width, height, or original.',
  },
  {
    icon: Bookmark01Icon,
    title: 'Bookmarks & Progress',
    description:
      'Bookmark any page with notes. Reading progress syncs across devices automatically.',
  },
  {
    icon: GridViewIcon,
    title: 'Collections',
    description:
      'Organize series into custom collections. Browse by genre, status, or your own groupings.',
  },
  {
    icon: UserMultiple02Icon,
    title: 'Multi-User',
    description:
      'Each user gets their own progress, bookmarks, and preferences. Admin panel for management.',
  },
  {
    icon: CloudIcon,
    title: 'AniList Integration',
    description:
      'Automatic metadata, cover art, and descriptions fetched from AniList.',
  },
  {
    icon: SmartPhone01Icon,
    title: 'PWA — Install Anywhere',
    description:
      'Install as a native app on iOS, Android, or desktop. Offline-capable with service worker caching.',
  },
  {
    icon: ShieldKeyIcon,
    title: 'Docker Ready',
    description:
      "Single multi-stage Docker image. docker compose up and you're running.",
  },
]

/* ------------------------------------------------------------------ */
/*  Screenshots                                                        */
/* ------------------------------------------------------------------ */
const screenshots = [
  {
    label: 'Library Home',
    description: 'Browse your entire collection at a glance.',
    src: '/screenshots/home.png',
  },
  {
    label: 'Series & Chapters',
    description: 'AniList metadata, chapter detection, and reading progress.',
    src: '/screenshots/series.png',
  },
  {
    label: 'Reader',
    description: 'Clean reading experience with multiple viewing modes.',
    src: '/screenshots/reader.png',
  },
]

/* ------------------------------------------------------------------ */
/*  Page                                                               */
/* ------------------------------------------------------------------ */
function HomePage() {
  return (
    <div className="mx-auto max-w-6xl border-x border-border">
      {/* Hero */}
      <section className="relative flex min-h-144 items-center overflow-hidden border-b border-border">
        {/* Grid pattern background */}
        <div className="pointer-events-none absolute inset-0 -z-10 bg-[linear-gradient(to_right,var(--border)_1px,transparent_1px),linear-gradient(to_bottom,var(--border)_1px,transparent_1px)] bg-size-[4rem_4rem] opacity-70" />
        {/* Accent glow */}
        <div className="pointer-events-none absolute top-0 left-1/2 -z-10 h-[40%] w-[70%] -translate-x-1/2 bg-[radial-gradient(ellipse_at_center,rgba(138,5,255,0.06)_0%,transparent_70%)]" />

        {/* Grid cell flashes — behind content */}
        <div
          className="pointer-events-none absolute inset-0"
          style={{ zIndex: 1 }}
        >
          {gridCells.map((cell, i) => (
            <div
              key={i}
              className="grid-cell-flash"
              data-cell={i}
              style={{
                left: cell.x,
                top: cell.y,
              }}
            />
          ))}
        </div>

        {/* Content — above traces */}
        <div className="relative z-10 w-full px-6 py-28 text-center md:py-38.5">
          <AnimatedLogo />

          <h1 className="mx-auto max-w-3xl text-4xl font-bold tracking-tight md:text-6xl">
            Your manga library,{' '}
            <span className="text-foreground">your server.</span>
          </h1>

          <p className="mx-auto mt-4 max-w-2xl text-lg text-muted-foreground md:text-xl">
            A self-hosted manga &amp; comic book reader. Like Jellyfin, but for
            CBZ files. Zero extraction, multi-user, installable as a PWA.
          </p>

          <div className="mt-10 flex flex-wrap items-center justify-center gap-4">
            <Link
              to="/docs"
              className="btn-get-started inline-flex items-center gap-2 px-6 py-3 text-sm font-semibold text-white"
            >
              Get Started
              <HugeiconsIcon icon={ArrowRight01Icon} size={16} />
            </Link>
            <a
              href="https://github.com/openreader/openpanel"
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center gap-2 border border-border bg-background px-6 py-3 text-sm font-semibold text-muted-foreground transition-colors hover:text-foreground hover:border-foreground/30"
            >
              View on GitHub
            </a>
          </div>
        </div>
      </section>

      {/* Architecture — boxed grid */}
      <section className="border-b border-border">
        <div className="px-6 py-16 md:py-20">
          <div className="grid gap-px bg-border md:grid-cols-3">
            {[
              {
                label: 'Backend',
                tech: 'Rust + Axum',
                desc: 'High-performance async HTTP server with SQLite (WAL mode). ZIP central directories are parsed once and cached in an LRU cache.',
              },
              {
                label: 'Frontend',
                tech: 'React 19 + Vite',
                desc: 'TanStack Router, Zustand, Tailwind v4. Fully responsive SPA with PWA support and service worker caching.',
              },
              {
                label: 'Storage',
                tech: 'CBZ on Disk',
                desc: 'Pages are read by seeking directly into ZIP archives — no extraction, no temp files, no wasted disk space.',
              },
            ].map((item) => (
              <div key={item.label} className="bg-background p-6">
                <p className="mb-1 text-xs font-semibold uppercase tracking-wider text-muted-foreground">
                  {item.label}
                </p>
                <p className="text-lg font-bold">{item.tech}</p>
                <p className="mt-2 text-sm text-muted-foreground">
                  {item.desc}
                </p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Features grid */}
      <section className="border-b border-border">
        <div className="px-6 py-20 md:py-28">
          <div className="mb-12 text-center">
            <h2 className="text-3xl font-bold tracking-tight md:text-4xl">
              Everything you need
            </h2>
            <p className="mt-3 text-muted-foreground">
              Built for manga and comic readers who want full control.
            </p>
          </div>
          <div className="grid gap-px bg-border sm:grid-cols-2 lg:grid-cols-3">
            {features.map((f) => (
              <div
                key={f.title}
                className="group bg-background p-6 transition-colors"
              >
                <div className="mb-4 flex h-10 w-10 items-center justify-center border-border text-foreground">
                  <HugeiconsIcon icon={f.icon} size={20} />
                </div>
                <h3 className="mb-2 font-semibold">{f.title}</h3>
                <p className="text-sm leading-relaxed text-muted-foreground">
                  {f.description}
                </p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Screenshots */}
      <section className="border-b border-border">
        <div className="px-6 py-20 md:py-28">
          <div className="mb-12 text-center">
            <h2 className="text-3xl font-bold tracking-tight md:text-4xl">
              See it in action
            </h2>
            <p className="mt-3 text-muted-foreground">
              A clean, fast reading experience across every device.
            </p>
          </div>
          <div className="grid gap-6 md:grid-cols-3">
            {screenshots.map((s) => (
              <div key={s.label} className="group">
                <div className="relative aspect-4/3 overflow-hidden border border-border bg-black flex items-center justify-center">
                  <img
                    src={s.src}
                    alt={s.label}
                    className="h-full w-full object-cover object-top opacity-90 transition-opacity group-hover:opacity-100"
                    onError={(e) => {
                      e.currentTarget.style.display = 'none'
                    }}
                  />
                  <span className="absolute text-sm text-muted-foreground pointer-events-none">
                    {s.label}
                  </span>
                </div>
                <h3 className="mt-3 font-semibold">{s.label}</h3>
                <p className="text-sm text-muted-foreground">{s.description}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* CTA */}
      <section>
        <div className="px-6 py-20 text-center">
          <h2 className="text-3xl font-bold tracking-tight">
            Ready to try it?
          </h2>
          <p className="mt-3 text-muted-foreground">
            Self-host in minutes with Docker or build from source.
          </p>
          <div className="mt-8 flex flex-wrap items-center justify-center gap-4">
            <Link
              to="/docs"
              className="inline-flex items-center gap-2 bg-foreground px-6 py-3 text-sm font-semibold text-background transition-colors hover:bg-foreground/90"
            >
              Read the Docs
              <HugeiconsIcon icon={ArrowRight01Icon} size={16} />
            </Link>
          </div>
        </div>
      </section>
    </div>
  )
}
