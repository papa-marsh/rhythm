// icons.jsx — minimal line icons. <Icon name size strokeWidth /> uses currentColor.
// Exports to window: Icon

const ICON_PATHS = {
  // ── tab bar ──
  today: '<rect x="3" y="4.5" width="18" height="16.5" rx="3.2"/><path d="M3 9h18"/><path d="M8 2.5v4M16 2.5v4"/><circle cx="12" cy="14.5" r="1.6" fill="currentColor" stroke="none"/>',
  cadences: '<path d="M17 2.5l3.2 3.2L17 9"/><path d="M20 5.7H8.5A4.5 4.5 0 0 0 4 10.2v.8"/><path d="M7 21.5l-3.2-3.2L7 15"/><path d="M4 18.3h11.5a4.5 4.5 0 0 0 4.5-4.5v-.8"/>',
  discovery: '<circle cx="12" cy="12" r="9"/><path d="M15.5 8.5l-2.1 5-5 2.1 2.1-5z" fill="currentColor" stroke="none"/>',
  settings: '<path d="M9.9 4.1 L9.9 1.2 L14.1 1.2 L14.1 4.1 L16.1 4.9 L18.2 2.9 L21.1 5.8 L19.1 7.9 L19.9 9.9 L22.8 9.9 L22.8 14.1 L19.9 14.1 L19.1 16.1 L21.1 18.2 L18.2 21.1 L16.1 19.1 L14.1 19.9 L14.1 22.8 L9.9 22.8 L9.9 19.9 L7.9 19.1 L5.8 21.1 L2.9 18.2 L4.9 16.1 L4.1 14.1 L1.2 14.1 L1.2 9.9 L4.1 9.9 L4.9 7.9 L2.9 5.8 L5.8 2.9 L7.9 4.9 Z"/><circle cx="12" cy="12" r="3.4"/>',
  anchor: '<circle cx="12" cy="4.4" r="2.3"/><path d="M12 6.7V21"/><path d="M8 9.6h8"/><path d="M4.4 12.6a7.6 7.6 0 0 0 15.2 0"/><path d="M4.4 12.6l-1.6 1.1M19.6 12.6l1.6 1.1"/>',

  // ── ui ──
  plus: '<path d="M12 5v14M5 12h14"/>',
  check: '<path d="M4 12.5l5 5 11-12"/>',
  checkThin: '<path d="M5 12.5l4.5 4.5L19 7"/>',
  chevron: '<path d="M9 5l7 7-7 7"/>',
  chevronDown: '<path d="M5 9l7 7 7-7"/>',
  back: '<path d="M15 5l-7 7 7 7"/>',
  close: '<path d="M6 6l12 12M18 6L6 18"/>',
  bell: '<path d="M18 9a6 6 0 1 0-12 0c0 7-2.5 8.5-2.5 8.5h17S18 16 18 9z"/><path d="M13.7 20.5a2 2 0 0 1-3.4 0"/>',
  bellOff: '<path d="M9 6.2A6 6 0 0 1 18 9c0 2.7.4 4.6.9 6M6 9c0 7-2.5 8.5-2.5 8.5h13M13.7 20.5a2 2 0 0 1-3.4 0M3 3l18 18"/>',
  clock: '<circle cx="12" cy="12" r="8.5"/><path d="M12 7.5V12l3 2"/>',
  snooze: '<path d="M8 8h5l-5 8h5"/><path d="M14.5 4h4l-4 5h4" stroke-width="1.4"/>',
  skip: '<path d="M6 4.5l9 7.5-9 7.5z" fill="currentColor" stroke="none"/><rect x="16.4" y="4.5" width="2.5" height="15" rx="1.2" fill="currentColor" stroke="none"/>',
  ellipsis: '<circle cx="5" cy="12" r="1.6" fill="currentColor" stroke="none"/><circle cx="12" cy="12" r="1.6" fill="currentColor" stroke="none"/><circle cx="19" cy="12" r="1.6" fill="currentColor" stroke="none"/>',
  pencil: '<path d="M4 20l4-1 11-11-3-3L5 16z"/><path d="M13.5 6.5l3 3"/>',
  trash2: '<path d="M4 7h16M9 7V4.5h6V7M6 7l1 13h10l1-13"/>',
  calendar: '<rect x="3.5" y="5" width="17" height="16" rx="3"/><path d="M3.5 9.5h17M8 3v4M16 3v4"/>',
  flag: '<path d="M6 21V4M6 4h11l-2 3.5L17 11H6"/>',
  repeat: '<path d="M17 2.5l3 3-3 3"/><path d="M20 5.5H9A5 5 0 0 0 4 10.5"/><path d="M7 21.5l-3-3 3-3"/><path d="M4 18.5h11a5 5 0 0 0 5-5"/>',
  target: '<circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="5"/><circle cx="12" cy="12" r="1.4" fill="currentColor" stroke="none"/>',
  history: '<path d="M3.5 12a8.5 8.5 0 1 0 2.6-6.1L3.5 8"/><path d="M3.5 4v4h4"/><path d="M12 8v4.3l3 1.7"/>',
  moon: '<path d="M20 13.5A8 8 0 1 1 10.5 4 6.3 6.3 0 0 0 20 13.5z"/>',
  sun: '<circle cx="12" cy="12" r="4"/><path d="M12 2.5v2.2M12 19.3v2.2M21.5 12h-2.2M4.7 12H2.5M18.4 5.6l-1.6 1.6M7.2 16.8l-1.6 1.6M18.4 18.4l-1.6-1.6M7.2 7.2L5.6 5.6"/>',
  speaker: '<path d="M4 9v6h3.5L13 20V4L7.5 9z"/><path d="M16 9a4 4 0 0 1 0 6M18.5 6.5a7.5 7.5 0 0 1 0 11"/>',
  vibrate: '<rect x="8.5" y="4" width="7" height="16" rx="2"/><path d="M4 8v8M20 8v8" stroke-width="1.5"/>',
  info: '<circle cx="12" cy="12" r="9"/><path d="M12 11v5"/><circle cx="12" cy="7.8" r="1.1" fill="currentColor" stroke="none"/>',
  arrowRight: '<path d="M5 12h14M13 6l6 6-6 6"/>',
  sparkles: '<path d="M12 3l1.6 4.4L18 9l-4.4 1.6L12 15l-1.6-4.4L6 9l4.4-1.6z"/><path d="M18.5 14.5l.8 2.2 2.2.8-2.2.8-.8 2.2-.8-2.2-2.2-.8 2.2-.8z"/>',
  search: '<circle cx="11" cy="11" r="7"/><path d="M20.5 20.5l-4.5-4.5"/>',
  sort: '<path d="M7 4v15"/><path d="M4 16l3 3 3-3"/><path d="M17 20V5"/><path d="M14 8l3-3 3 3"/>',

  // ── cadence glyphs ──
  leaf: '<path d="M4 20C4 11 11 4 20 4c0 9-7 16-16 16z"/><path d="M4 20C8 16 12 13 16 11"/>',
  trash: '<path d="M4 7h16M9 7V4.5h6V7M6 7l1 13h10l1-13"/>',
  wind: '<path d="M3 8h11a2.5 2.5 0 1 0-2.5-2.5"/><path d="M3 16h14a2.5 2.5 0 1 1-2.5 2.5"/><path d="M3 12h7a2 2 0 1 0-2-2"/>',
  bolt: '<path d="M13 2L4 13h6l-1 9 9-12h-6z"/>',
  scissors: '<circle cx="6" cy="6" r="2.5"/><circle cx="6" cy="18" r="2.5"/><path d="M8 8l12 9M8 16L20 7"/>',
  sprout: '<path d="M12 20v-7"/><path d="M12 13C12 9 8.5 6.5 4.5 7 4 11 7.5 13.5 12 13z"/><path d="M12 11C12 7.5 15 5 19 5.5 19.5 9 16 11.5 12 11z"/>',
  drop: '<path d="M12 3C12 3 5 11 5 15a7 7 0 0 0 14 0C19 11 12 3 12 3z"/>',
  home: '<path d="M4 11l8-7 8 7"/><path d="M6 9.5V20h12V9.5"/>',
  sparkle: '<path d="M12 3l1.8 5.2L19 10l-5.2 1.8L12 17l-1.8-5.2L5 10l5.2-1.8z"/>',
  book: '<path d="M5 4.5h10a2 2 0 0 1 2 2V20H7a2 2 0 0 0-2 2z"/><path d="M5 4.5V20"/><path d="M17 6.5h2v15h-2"/>',
  phone: '<path d="M6 3.5h4l1.5 4.5-2.5 2a12 12 0 0 0 5 5l2-2.5 4.5 1.5v4a2 2 0 0 1-2 2C11 19.5 4.5 13 4.5 5.5a2 2 0 0 1 1.5-2z"/>',
  globe: '<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3c2.8 3 2.8 15 0 18M12 3c-2.8 3-2.8 15 0 18"/>',
};

function Icon({ name, size = 24, strokeWidth = 1.8, style = {}, color }) {
  const d = ICON_PATHS[name] || ICON_PATHS.info;
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none"
      stroke={color || 'currentColor'} strokeWidth={strokeWidth}
      strokeLinecap="round" strokeLinejoin="round"
      style={{ display: 'block', flexShrink: 0, ...style }}
      dangerouslySetInnerHTML={{ __html: d }} />
  );
}

window.Icon = Icon;
