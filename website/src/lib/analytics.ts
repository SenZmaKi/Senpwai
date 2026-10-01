type EventData = Record<string, string>;

type AnalyticsWindow = Window & {
  umami?: { track: (name: string, data: EventData) => Promise<unknown> };
};

const base = import.meta.env.BASE_URL.replace(/\/$/, '');

function pageName(path: string) {
  const relative = path.slice(base.length).replace(/\/$/, '') || '/';
  return ({ '/': 'home', '/download': 'downloads', '/legal': 'legal' } as Record<string, string>)[relative] ?? relative;
}

function track(name: string, data: EventData) {
  const analytics = (window as AnalyticsWindow).umami;
  // Analytics must never interrupt an interaction, including when blocked.
  try {
    void analytics?.track(name, {
      source_page: pageName(window.location.pathname),
      source_path: window.location.pathname,
      ...data,
    })?.catch(() => {});
  } catch {
    // The website remains usable if the tracker fails.
  }
}

if (import.meta.env.PROD) {
  function trackInteraction(event: MouseEvent) {
    if (event.type === 'auxclick' && event.button !== 1) return;
    if (!(event.target instanceof Element)) return;
    const target = event.target.closest<HTMLElement>('a, button, .wheel-card');
    if (!target) return;

    const location = target.closest('#mobile-menu') ? 'mobile-navigation'
      : target.closest('.desktop-nav') ? 'desktop-navigation'
      : target.closest('header') ? 'navigation'
      : target.closest('footer') ? 'footer'
      : target.closest('.hero') ? 'hero'
      : target.closest('#closing-section') ? 'community-section'
      : target.closest('#showcase') ? 'showcase'
      : target.closest('#themes') ? 'themes'
      : target.closest('.dl-card') ? 'download-card'
      : 'content';
    const context = {
      location,
      control: target.getAttribute('aria-label') ?? target.textContent?.trim().replace(/\s+/g, ' ') ?? '',
    };

    if (target.matches('.dl-button')) {
      const card = target.closest<HTMLElement>('.dl-card');
      if (!card) return;
      track('download-click', {
        ...context,
        platform: card.dataset.platformId ?? '',
        architecture: card.querySelector<HTMLSelectElement>('.architecture-select')?.value ?? 'universal',
        version: card.dataset.version ?? '',
        destination: target instanceof HTMLAnchorElement ? `${new URL(target.href).origin}${new URL(target.href).pathname}` : '',
        destination_type: 'release-asset',
      });
    } else if (target instanceof HTMLAnchorElement) {
      const url = new URL(target.href);
      if (url.origin === window.location.origin) {
        const destination = pageName(url.pathname);
        if (url.pathname === `${base}/download`) {
          track('download-page-click', { ...context, destination, destination_path: url.pathname });
        } else if (url.hash && url.hash !== '#main-content') {
          track('section-click', { ...context, section: url.hash.slice(1), destination, destination_path: url.pathname });
        } else if (!url.hash) {
          track('page-navigation', { ...context, destination, destination_path: url.pathname });
        }
      } else {
        const repository = 'https://github.com/SenZmaKi/Senpwai';
        const destinationUrl = `${url.origin}${url.pathname}`;
        const destinations: Record<string, [string, string]> = {
          [repository]: ['repository-click', 'github-repository'],
          [`${repository}/releases`]: ['releases-click', 'github-releases'],
          [`${repository}/issues`]: ['support-click', 'github-issues'],
          'https://discord.gg/invite/e9UxkuyDX2': ['community-click', 'discord'],
          'https://www.reddit.com/r/Senpwai': ['community-click', 'reddit'],
        };
        const [name, destinationType] = destinations[destinationUrl.replace(/\/$/, '')] ?? ['outbound-click', 'external'];
        track(name, { ...context, destination: destinationUrl, destination_type: destinationType });
      }
    } else if (target.matches('.mac-help-trigger')) {
      track('macos-help-open', { ...context, platform: 'macos' });
    } else if (target.matches('.icon-tab')) {
      track('showcase-select', { ...context, screen: target.getAttribute('aria-label') ?? '' });
    } else if (target.matches('.theme-pill, .wheel-card')) {
      const theme = target.matches('.wheel-card')
        ? target.querySelector('img')?.alt
        : target.textContent?.trim();
      track('theme-select', { ...context, theme: theme ?? '' });
    }
  }

  document.addEventListener('click', trackInteraction);
  document.addEventListener('auxclick', trackInteraction);
}
