import tr from '@shared/l10n/tr.json';

type Tree = { [k: string]: string | Tree };

/** t('menu.overview') -> "Genel Bakış". {param} yer tutucuları desteklenir. Bulunamazsa anahtar döner. */
export function t(key: string, params?: Record<string, string | number>): string {
  let node: string | Tree | undefined = tr as Tree;
  for (const part of key.split('.')) {
    if (node && typeof node === 'object') node = node[part];
    else { node = undefined; break; }
  }
  if (typeof node !== 'string') return key;
  return params ? node.replace(/\{(\w+)\}/g, (_, k: string) => String(params[k] ?? `{${k}}`)) : node;
}
