import tokens from '@shared/design-tokens.json';

/** design-tokens.json -> CSS değişkenleri (kodda sabit renk yok). */
export function applyTokens(root: HTMLElement = document.documentElement): void {
  const set = (k: string, v: string | number) => root.style.setProperty(k, String(v));
  for (const [k, v] of Object.entries(tokens.color)) set(`--c-${k}`, v);
  for (const [k, v] of Object.entries(tokens.radius)) set(`--r-${k}`, `${v}px`);
  for (const [k, v] of Object.entries(tokens.spacing)) set(`--s-${k}`, `${v}px`);
  for (const [k, v] of Object.entries(tokens.typography.size)) set(`--fs-${k}`, `${v}px`);
  for (const [k, v] of Object.entries(tokens.typography.weight)) set(`--fw-${k}`, v);
  const d = tokens.layout.desktop;
  set('--sidebar-w', `${d.sidebarWidth}px`);
  set('--sidebar-w-collapsed', `${d.sidebarCollapsedWidth}px`);
  set('--topbar-h', `${d.topbarHeight}px`);
  set('--shadow-card', tokens.shadow.card);
  set('--c-glass', tokens.theme.glass);
  for (const [k, v] of Object.entries(tokens.status)) set(`--st-${k}`, v.color);
}

export { tokens };
