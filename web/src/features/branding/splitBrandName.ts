/**
 * Splits a brand name so its final segment can carry the accent colour:
 * "TradieFixo" → ["Tradie", "Fixo"], "Acme Trade" → ["Acme", "Trade"].
 * Works for any partner name rather than assuming this one's shape.
 */
export function splitBrandName(name: string): [string, string] {
  // Last start-of-word boundary: an uppercase letter preceded by a lowercase one.
  const match = /(?<=([a-z0-9]))([A-Z])/g;
  let last = -1;
  let m: RegExpExecArray | null;
  while ((m = match.exec(name)) !== null) last = m.index;

  if (last <= 0) return [name, ''];
  return [name.slice(0, last), name.slice(last)];
}
