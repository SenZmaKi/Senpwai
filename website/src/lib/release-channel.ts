export const repo = 'https://github.com/SenZmaKi/Senpwai';

type Asset = { name: string; browser_download_url: string };
type Release = { tag_name: string; draft: boolean; prerelease: boolean; assets: Asset[] };
const api = 'https://api.github.com/repos/SenZmaKi/Senpwai/releases';

export async function loadChannel(channel: 'stable' | 'nightly') {
  const response = await fetch(`${api}?per_page=100`);
  if (!response.ok) throw new Error(`Release lookup failed: ${response.status}`);
  const data: Release[] = await response.json();
  const release = data.find((item) =>
    !item.draft && item.tag_name.includes('-nightly.') === (channel === 'nightly'));
  if (!release) throw new Error('No published release yet');
  return release;
}

export function assetFor(assets: Asset[], platform: string, architecture: string) {
  const suffix = platform === 'android' ? `-${architecture}.apk`
    : platform === 'linux' ? `-${architecture === 'x64' ? 'x86_64' : 'aarch64'}.AppImage`
    : platform === 'windows' ? `-windows-${architecture}-setup.exe`
    : '-macos-universal.dmg';
  return assets.find((asset) => asset.name.startsWith('Senpwai-') && asset.name.endsWith(suffix));
}

export const nightlyReleases = `${repo}/releases?q=nightly&expanded=true`;
