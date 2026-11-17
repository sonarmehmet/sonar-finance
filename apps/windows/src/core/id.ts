/** İstemci tarafı ID (UUID v4, küçük harf) — docs/02. */
export function newId(): string {
  return crypto.randomUUID().toLowerCase();
}
