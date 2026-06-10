// ui.jsx — theme + iOS UI primitives
// Exports: makeTheme, ThemeCtx, useTheme, hair, GlyphTile, ScreenScaffold,
//          TabBar, Section, Row, Segmented, Switch, Stepper, Sheet, ActionSheet,
//          NavBtn, Chip, BigButton, STATUS_H, TABBAR_H

const { createContext, useContext, useState, useEffect, useRef, useCallback } = React;

const STATUS_H = 56;
const TABBAR_H = 86;

function makeTheme(appearance, accent, showEmoji = true) {
  const dark = appearance === 'dark';
  const acc = accent || '#5E5CE6';
  const accDark = dark ? lighten(acc, 0.16) : acc;
  return {
    dark, accent: dark ? accDark : acc, showEmoji,
    bg: dark ? '#000000' : '#F2F2F7',
    groupBg: dark ? '#000000' : '#F2F2F7',
    card: dark ? '#1C1C1E' : '#FFFFFF',
    card2: dark ? '#2C2C2E' : '#FFFFFF',
    fill: dark ? 'rgba(118,118,128,0.24)' : 'rgba(118,118,128,0.12)',
    fill2: dark ? 'rgba(118,118,128,0.16)' : 'rgba(118,118,128,0.08)',
    label: dark ? '#FFFFFF' : '#000000',
    label2: dark ? 'rgba(235,235,245,0.6)' : 'rgba(60,60,67,0.6)',
    label3: dark ? 'rgba(235,235,245,0.3)' : 'rgba(60,60,67,0.3)',
    sep: dark ? 'rgba(84,84,88,0.6)' : 'rgba(60,60,67,0.16)',
    navBg: dark ? 'rgba(20,20,22,0.72)' : 'rgba(249,249,251,0.8)',
    tier: {
      later: dark ? 'rgba(235,235,245,0.4)' : 'rgba(60,60,67,0.45)',
      almost: dark ? accDark : acc,
      due: dark ? accDark : acc,
      overdue: dark ? '#FF9F0A' : '#FF9500',
      late: dark ? '#FF453A' : '#FF3B30',
    },
    green: dark ? '#30D158' : '#34C759',
    orange: dark ? '#FF9F0A' : '#FF9500',
    red: dark ? '#FF453A' : '#FF3B30',
  };
}
function lighten(hex, amt) {
  const n = parseInt(hex.slice(1), 16);
  let r = (n >> 16) & 255, g = (n >> 8) & 255, b = n & 255;
  r = Math.round(r + (255 - r) * amt); g = Math.round(g + (255 - g) * amt); b = Math.round(b + (255 - b) * amt);
  return `#${((1 << 24) + (r << 16) + (g << 8) + b).toString(16).slice(1)}`;
}
function hexA(hex, a) {
  const n = parseInt(hex.slice(1), 16);
  return `rgba(${(n >> 16) & 255},${(n >> 8) & 255},${n & 255},${a})`;
}

const ThemeCtx = createContext(makeTheme('light'));
const useTheme = () => useContext(ThemeCtx);

const SF = '-apple-system, BlinkMacSystemFont, "SF Pro Text", "SF Pro Display", system-ui, sans-serif';

// ── Colored rounded glyph tile (emoji identity) ──
function GlyphTile({ glyph, color, size = 29, radius }) {
  const t = useTheme();
  if (t && t.showEmoji === false) return null;
  return (
    <div style={{
      width: size, height: size, borderRadius: radius ?? size * 0.29, background: color,
      display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0,
      boxShadow: `0 1px 2px ${hexA(color, 0.4)}`,
    }}>
      <span style={{ fontSize: size * 0.56, lineHeight: 1, transform: 'translateY(0.5px)' }}>{glyph}</span>
    </div>
  );
}

// ── Screen scaffold with collapsing large title ──
function ScreenScaffold({ title, subtitle, leading, trailing, children, scrollRef, big = true, search, onSearch, searchPlaceholder }) {
  const t = useTheme();
  const innerRef = useRef(null);
  const ref = scrollRef || innerRef;
  const searchRef = useRef(null);
  const searchOffsetRef = useRef(0);
  const [p, setP] = useState(0);
  const onScroll = useCallback(() => {
    const y = ref.current ? ref.current.scrollTop : 0;
    setP(Math.max(0, Math.min(1, (y - searchOffsetRef.current - 6) / 34)));
  }, [ref]);
  // Tuck the search bar off-screen above the title; pull down to reveal it.
  useEffect(() => {
    if (onSearch && ref.current && searchRef.current && !search) {
      const h = searchRef.current.offsetHeight;
      searchOffsetRef.current = h;
      ref.current.scrollTop = h;
    }
  }, []);
  return (
    <div style={{ position: 'absolute', inset: 0, background: t.bg, overflow: 'hidden' }}>
      {/* scroll area */}
      <div ref={ref} onScroll={onScroll} style={{
        position: 'absolute', inset: 0, overflowY: 'auto', overflowX: 'hidden',
        paddingTop: big ? STATUS_H + 44 : STATUS_H + 44,
        paddingBottom: TABBAR_H + 24, WebkitOverflowScrolling: 'touch',
      }}>
        {onSearch && (
          <div ref={searchRef} style={{ padding: '0 16px 8px' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 6, background: t.fill, borderRadius: 10, padding: '7px 9px' }}>
              <Icon name="search" size={17} strokeWidth={2} color={t.label2} />
              <input value={search} onChange={(e) => onSearch(e.target.value)} placeholder={searchPlaceholder || 'Search'}
                style={{ flex: 1, border: 'none', outline: 'none', background: 'transparent', fontFamily: SF, fontSize: 16, color: t.label, letterSpacing: -0.2 }} />
              {search ? <button onClick={() => onSearch('')} style={{ border: 'none', background: t.label3, borderRadius: 999, cursor: 'pointer', width: 17, height: 17, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 0, flexShrink: 0 }}><Icon name="close" size={11} strokeWidth={2.6} color={t.dark ? '#1C1C1E' : '#fff'} /></button> : null}
            </div>
          </div>
        )}
        {big && (
          <div style={{ padding: '4px 20px 8px' }}>
            <div style={{ fontFamily: SF, fontSize: 34, fontWeight: 800, letterSpacing: 0.36, color: t.label, lineHeight: '40px' }}>{title}</div>
            {subtitle && <div style={{ fontFamily: SF, fontSize: 15, fontWeight: 500, color: t.label2, marginTop: 3 }}>{subtitle}</div>}
          </div>
        )}
        {children}
      </div>
      {/* inline nav bar */}
      <div style={{
        position: 'absolute', top: 0, left: 0, right: 0, height: STATUS_H + 44, zIndex: 30,
        pointerEvents: 'none',
      }}>
        <div style={{ position: 'absolute', inset: 0, background: t.bg }} />
        <div style={{
          position: 'absolute', inset: 0, background: t.navBg,
          backdropFilter: 'saturate(180%) blur(20px)', WebkitBackdropFilter: 'saturate(180%) blur(20px)',
          opacity: p, transition: 'opacity .15s', borderBottom: `0.5px solid ${hexA(t.dark ? '#000' : '#000', p * 0.16)}`,
        }} />
        <div style={{ position: 'absolute', left: 0, right: 0, bottom: 0, height: 44, display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '0 8px', pointerEvents: 'auto' }}>
          <div style={{ minWidth: 76, display: 'flex', justifyContent: 'flex-start' }}>{leading}</div>
          <div style={{ flex: 1, textAlign: 'center', fontFamily: SF, fontSize: 17, fontWeight: 600, color: t.label, opacity: p, transition: 'opacity .15s', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{title}</div>
          <div style={{ minWidth: 76, display: 'flex', justifyContent: 'flex-end' }}>{trailing}</div>
        </div>
      </div>
    </div>
  );
}

function NavBtn({ children, onClick, accent, bold, disabled }) {
  const t = useTheme();
  return (
    <button onClick={disabled ? undefined : onClick} style={{
      border: 'none', background: 'none', cursor: disabled ? 'default' : 'pointer',
      fontFamily: SF, fontSize: 17, fontWeight: bold ? 600 : 400,
      color: disabled ? t.label3 : (accent !== false ? t.accent : t.label),
      padding: '6px 10px', display: 'flex', alignItems: 'center', gap: 2,
    }}>{children}</button>
  );
}

// ── Tab bar ──
const TABS = [
  { id: 'today', label: 'Today', icon: 'today' },
  { id: 'cadences', label: 'Cadences', icon: 'cadences' },
  { id: 'discovery', label: 'Discovery', icon: 'discovery' },
  { id: 'settings', label: 'Settings', icon: 'settings' },
];
function TabBar({ tab, onTab }) {
  const t = useTheme();
  return (
    <div style={{
      position: 'absolute', left: 0, right: 0, bottom: 0, height: TABBAR_H, zIndex: 40,
      paddingBottom: 22, display: 'flex',
      background: t.navBg, backdropFilter: 'saturate(180%) blur(20px)', WebkitBackdropFilter: 'saturate(180%) blur(20px)',
      borderTop: `0.5px solid ${t.sep}`,
    }}>
      {TABS.map(tb => {
        const on = tab === tb.id;
        return (
          <button key={tb.id} onClick={() => onTab(tb.id)} style={{
            flex: 1, border: 'none', background: 'none', cursor: 'pointer',
            display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4, paddingTop: 9,
            color: on ? t.accent : t.label2,
          }}>
            <Icon name={tb.icon} size={26} strokeWidth={on ? 2 : 1.7} />
            <span style={{ fontFamily: SF, fontSize: 10.5, fontWeight: on ? 600 : 500, letterSpacing: 0.1 }}>{tb.label}</span>
          </button>
        );
      })}
    </div>
  );
}

// ── Grouped section ──
function Section({ header, footer, children, first }) {
  const t = useTheme();
  return (
    <div style={{ marginTop: first ? 14 : 26 }}>
      {header && <div style={{ fontFamily: SF, fontSize: 13, fontWeight: 400, color: t.label2, padding: '0 32px 7px', textTransform: 'uppercase', letterSpacing: 0.2 }}>{header}</div>}
      <div style={{ background: t.card, borderRadius: 12, margin: '0 16px', overflow: 'hidden' }}>{children}</div>
      {footer && <div style={{ fontFamily: SF, fontSize: 13, fontWeight: 400, color: t.label2, padding: '7px 32px 0', lineHeight: '17px' }}>{footer}</div>}
    </div>
  );
}

function Row({ left, title, subtitle, value, accessory = 'chevron', onClick, last, danger, tint, height, align = 'center', titleWeight }) {
  const t = useTheme();
  return (
    <div onClick={onClick} style={{
      display: 'flex', alignItems: align, gap: 12, padding: '0 16px', minHeight: height || 46,
      position: 'relative', cursor: onClick ? 'pointer' : 'default',
    }}>
      {left && <div style={{ display: 'flex', alignItems: 'center', paddingTop: align === 'flex-start' ? 11 : 0 }}>{left}</div>}
      <div style={{ flex: 1, minWidth: 0, padding: '9px 0' }}>
        <div style={{ fontFamily: SF, fontSize: 17, fontWeight: titleWeight || 400, color: danger ? t.red : (tint || t.label), letterSpacing: -0.2, lineHeight: '21px' }}>{title}</div>
        {subtitle && <div style={{ fontFamily: SF, fontSize: 13.5, color: t.label2, marginTop: 2, lineHeight: '18px' }}>{subtitle}</div>}
      </div>
      {value != null && <div style={{ fontFamily: SF, fontSize: 17, color: t.label2, letterSpacing: -0.2, whiteSpace: 'nowrap' }}>{value}</div>}
      {accessory === 'chevron' && <Icon name="chevron" size={15} strokeWidth={2.4} color={t.label3} />}
      {accessory === 'check' && <Icon name="checkThin" size={18} strokeWidth={2.4} color={t.accent} />}
      {typeof accessory === 'object' && accessory}
      {!last && <div style={{ position: 'absolute', left: left ? 58 : 16, right: 0, bottom: 0, height: 0.5, background: t.sep }} />}
    </div>
  );
}

// ── Segmented control ──
function Segmented({ options, value, onChange, small }) {
  const t = useTheme();
  return (
    <div style={{ display: 'flex', background: t.fill, borderRadius: 9, padding: 2, gap: 2 }}>
      {options.map(o => {
        const v = o.value ?? o; const lab = o.label ?? o;
        const on = v === value;
        return (
          <button key={v} onClick={() => onChange(v)} style={{
            flex: 1, border: 'none', cursor: 'pointer', borderRadius: 7,
            background: on ? t.card2 : 'transparent', color: t.label,
            boxShadow: on ? '0 1px 3px rgba(0,0,0,0.12), 0 0 0 0.5px rgba(0,0,0,0.04)' : 'none',
            fontFamily: SF, fontSize: small ? 13 : 14, fontWeight: on ? 600 : 500,
            padding: small ? '5px 4px' : '7px 6px', transition: 'background .15s',
          }}>{lab}</button>
        );
      })}
    </div>
  );
}

// ── Switch ──
function Switch({ on, onChange, color }) {
  const t = useTheme();
  return (
    <button onClick={() => onChange(!on)} style={{
      width: 51, height: 31, borderRadius: 31, border: 'none', cursor: 'pointer', padding: 0,
      background: on ? (color || t.green) : (t.dark ? 'rgba(120,120,128,0.32)' : 'rgba(120,120,128,0.16)'),
      position: 'relative', transition: 'background .2s', flexShrink: 0,
    }}>
      <div style={{
        width: 27, height: 27, borderRadius: 27, background: '#fff', position: 'absolute', top: 2,
        left: on ? 22 : 2, transition: 'left .2s cubic-bezier(.3,1.3,.5,1)', boxShadow: '0 2px 5px rgba(0,0,0,0.2)',
      }} />
    </button>
  );
}

function parseTime(v) {
  const m = /(\d+):(\d+)\s*(AM|PM)/i.exec(v || '9:00 AM');
  return m ? { h: +m[1], min: +m[2], ap: m[3].toUpperCase() } : { h: 9, min: 0, ap: 'AM' };
}
function fmtTime(h, min, ap) { return `${h}:${String(min).padStart(2, '0')} ${ap}`; }

function TimePickerPanel({ value, onChange }) {
  const t = useTheme();
  const { h, min, ap } = parseTime(value);
  const setH = (d) => { let n = h + d; if (n > 12) n = 1; if (n < 1) n = 12; onChange(fmtTime(n, min, ap)); };
  const setM = (d) => onChange(fmtTime(h, (min + d + 60) % 60, ap));
  const chev = (up, fn) => (
    <button onClick={fn} style={{ border: 'none', background: 'none', cursor: 'pointer', padding: 4, display: 'flex' }}>
      <Icon name="chevronDown" size={20} strokeWidth={2.4} color={t.accent} style={{ transform: up ? 'rotate(180deg)' : 'none' }} />
    </button>
  );
  const wheel = (display, onUp, onDown) => (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 1 }}>
      {chev(true, onUp)}
      <div style={{ fontFamily: SF, fontSize: 26, fontWeight: 600, color: t.label, minWidth: 46, textAlign: 'center', fontVariantNumeric: 'tabular-nums' }}>{display}</div>
      {chev(false, onDown)}
    </div>
  );
  return (
    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 10, padding: '8px 0 14px' }}>
      {wheel(h, () => setH(1), () => setH(-1))}
      <div style={{ fontFamily: SF, fontSize: 26, fontWeight: 600, color: t.label2, paddingBottom: 2 }}>:</div>
      {wheel(String(min).padStart(2, '0'), () => setM(5), () => setM(-5))}
      <div style={{ width: 92, marginLeft: 8 }}>
        <Segmented small options={[{ value: 'AM', label: 'AM' }, { value: 'PM', label: 'PM' }]} value={ap} onChange={(v) => onChange(fmtTime(h, min, v))} />
      </div>
    </div>
  );
}

function Chip({ children, color, bg, style }) {
  return (
    <span style={{
      fontFamily: SF, fontSize: 12.5, fontWeight: 600, color, background: bg,
      padding: '3px 8px', borderRadius: 7, letterSpacing: -0.1, whiteSpace: 'nowrap',
      display: 'inline-flex', alignItems: 'center', gap: 4, ...style,
    }}>{children}</span>
  );
}

function BigButton({ children, onClick, kind = 'primary', disabled, icon, danger }) {
  const t = useTheme();
  const primary = kind === 'primary';
  const bg = danger ? (t.dark ? 'rgba(255,69,58,0.15)' : 'rgba(255,59,48,0.1)') : primary ? t.accent : t.fill;
  const col = danger ? t.red : primary ? '#fff' : t.accent;
  return (
    <button onClick={disabled ? undefined : onClick} style={{
      width: '100%', border: 'none', borderRadius: 13, cursor: disabled ? 'default' : 'pointer',
      background: disabled ? t.fill : bg, color: disabled ? t.label3 : col, opacity: disabled ? 0.7 : 1,
      fontFamily: SF, fontSize: 17, fontWeight: 600, padding: '14px 16px',
      display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
    }}>{icon && <Icon name={icon} size={19} strokeWidth={2.2} />}{children}</button>
  );
}

// ── Bottom sheet ──
function Sheet({ open, onClose, children, height = 'auto', maxHeight = '94%', title, leftAction, rightAction }) {
  const t = useTheme();
  const [mounted, setMounted] = useState(open);
  const [shown, setShown] = useState(false);
  useEffect(() => {
    let raf, to;
    if (open) { setMounted(true); raf = requestAnimationFrame(() => requestAnimationFrame(() => setShown(true))); }
    else { setShown(false); to = setTimeout(() => setMounted(false), 340); }
    return () => { cancelAnimationFrame(raf); clearTimeout(to); };
  }, [open]);
  if (!mounted) return null;
  return (
    <div style={{ position: 'absolute', inset: 0, zIndex: 200, display: 'flex', flexDirection: 'column', justifyContent: 'flex-end' }}>
      <div onClick={onClose} style={{ position: 'absolute', inset: 0, background: 'rgba(0,0,0,0.4)', opacity: shown ? 1 : 0, transition: 'opacity .34s' }} />
      <div style={{
        position: 'relative', background: t.dark ? '#1C1C1E' : '#F2F2F7', borderRadius: '14px 14px 0 0',
        height, maxHeight, display: 'flex', flexDirection: 'column',
        transform: shown ? 'translateY(0)' : 'translateY(100%)', transition: 'transform .36s cubic-bezier(.32,.72,0,1)',
        boxShadow: '0 -8px 40px rgba(0,0,0,0.25)',
      }}>
        {(title || rightAction || leftAction) && (
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '0 8px', height: 54, flexShrink: 0, borderBottom: `0.5px solid ${t.sep}` }}>
            <div style={{ minWidth: 70, textAlign: 'left' }}>{leftAction || <NavBtn onClick={onClose}>Cancel</NavBtn>}</div>
            <div style={{ fontFamily: SF, fontSize: 17, fontWeight: 600, color: t.label }}>{title}</div>
            <div style={{ minWidth: 70, textAlign: 'right' }}>{rightAction || <div style={{ width: 1 }} />}</div>
          </div>
        )}
        <div style={{ flex: 1, overflowY: 'auto', WebkitOverflowScrolling: 'touch', paddingBottom: 40 }}>{children}</div>
      </div>
    </div>
  );
}

// ── Action sheet (floating card + cancel) ──
function ActionSheet({ open, onClose, title, message, actions = [], header }) {
  const t = useTheme();
  const [mounted, setMounted] = useState(open);
  const [shown, setShown] = useState(false);
  useEffect(() => {
    let raf, to;
    if (open) { setMounted(true); raf = requestAnimationFrame(() => requestAnimationFrame(() => setShown(true))); }
    else { setShown(false); to = setTimeout(() => setMounted(false), 300); }
    return () => { cancelAnimationFrame(raf); clearTimeout(to); };
  }, [open]);
  if (!mounted) return null;
  const blur = { backdropFilter: 'blur(28px) saturate(180%)', WebkitBackdropFilter: 'blur(28px) saturate(180%)' };
  const cardBg = t.dark ? 'rgba(46,46,49,0.82)' : 'rgba(255,255,255,0.82)';
  return (
    <div style={{ position: 'absolute', inset: 0, zIndex: 250, display: 'flex', flexDirection: 'column', justifyContent: 'flex-end', padding: 8 }}>
      <div onClick={onClose} style={{ position: 'absolute', inset: 0, background: 'rgba(0,0,0,0.28)', opacity: shown ? 1 : 0, transition: 'opacity .3s' }} />
      <div style={{ position: 'relative', transform: shown ? 'translateY(0)' : 'translateY(20px)', opacity: shown ? 1 : 0, transition: 'transform .3s cubic-bezier(.32,.72,0,1), opacity .3s' }}>
        <div style={{ borderRadius: 14, overflow: 'hidden', background: cardBg, ...blur, marginBottom: 8 }}>
          {(title || message || header) && (
            <div style={{ padding: header ? 0 : '15px 16px 14px', textAlign: 'center', borderBottom: `0.5px solid ${t.sep}` }}>
              {header}
              {title && <div style={{ fontFamily: SF, fontSize: 13, fontWeight: 600, color: t.label2 }}>{title}</div>}
              {message && <div style={{ fontFamily: SF, fontSize: 13, color: t.label2, marginTop: 3, lineHeight: '17px' }}>{message}</div>}
            </div>
          )}
          {actions.map((a, i) => (
            <button key={i} onClick={() => { a.onClick && a.onClick(); if (!a.keepOpen) onClose(); }} style={{
              width: '100%', border: 'none', background: 'none', cursor: 'pointer',
              padding: '17px 16px', fontFamily: SF, fontSize: 20, fontWeight: a.bold ? 600 : 400,
              color: a.destructive ? t.red : (a.color || t.accent),
              borderTop: i ? `0.5px solid ${t.sep}` : 'none', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
            }}>{a.icon && <Icon name={a.icon} size={20} strokeWidth={2} />}{a.label}</button>
          ))}
        </div>
        <button onClick={onClose} style={{
          width: '100%', border: 'none', borderRadius: 14, cursor: 'pointer',
          background: t.dark ? 'rgba(60,60,63,0.92)' : 'rgba(255,255,255,0.92)', ...blur,
          padding: '17px 16px', fontFamily: SF, fontSize: 20, fontWeight: 600, color: t.accent,
        }}>Cancel</button>
      </div>
    </div>
  );
}

Object.assign(window, {
  makeTheme, ThemeCtx, useTheme, hexA, lighten, SF, STATUS_H, TABBAR_H,
  GlyphTile, ScreenScaffold, NavBtn, TabBar, TABS, Section, Row, Segmented, Switch, Chip, BigButton, Sheet, ActionSheet, TimePickerPanel, parseTime, fmtTime,
});
