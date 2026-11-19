import { useEffect, useRef } from 'react';

/** Sade yıldız alanı: yavaş akan noktalar. Hareket azaltma tercihine saygı duyar. */
export function Starfield() {
  const ref = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const canvas = ref.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;
    const reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    let w = 0, h = 0, raf = 0;
    type Star = { x: number; y: number; z: number; tw: number };
    let stars: Star[] = [];

    const resize = () => {
      const dpr = Math.min(window.devicePixelRatio || 1, 2);
      w = canvas.clientWidth; h = canvas.clientHeight;
      canvas.width = w * dpr; canvas.height = h * dpr;
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      const n = Math.round((w * h) / 9000);
      stars = Array.from({ length: n }, () => ({ x: Math.random() * w, y: Math.random() * h, z: Math.random() * 0.9 + 0.1, tw: Math.random() * 6.28 }));
      if (reduce) draw(0);
    };

    const draw = (t: number) => {
      ctx.clearRect(0, 0, w, h);
      for (const s of stars) {
        const a = 0.35 + 0.45 * Math.sin(t / 900 + s.tw);
        ctx.globalAlpha = Math.max(0.1, a * s.z);
        ctx.fillStyle = s.z > 0.8 ? '#4DE3FF' : '#CFE3FF';
        ctx.fillRect(s.x, s.y, s.z * 1.8, s.z * 1.8);
        if (!reduce) { s.y += s.z * 0.12; if (s.y > h) { s.y = 0; s.x = Math.random() * w; } }
      }
      ctx.globalAlpha = 1;
    };

    const loop = (t: number) => { draw(t); raf = requestAnimationFrame(loop); };
    resize();
    if (!reduce) raf = requestAnimationFrame(loop);
    window.addEventListener('resize', resize);
    return () => { cancelAnimationFrame(raf); window.removeEventListener('resize', resize); };
  }, []);

  return <canvas ref={ref} className="starfield" aria-hidden="true" />;
}
