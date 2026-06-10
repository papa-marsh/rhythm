// beat.jsx — beat row with urgency + action variations, swipe mechanics
// Exports: BeatRow, ProgressRing, DueChip, CheckCircle, urgencyWindow

const { urgencyOf } = window.RhythmData;

// progress through the attention window: 0 at (due-grace), .5 at due, 1 at (due+grace)
function urgencyWindow(beat) {
  const { daysBetween, TODAY } = window.RhythmData;
  const off = daysBetween(TODAY, beat.due);
  const g = Math.max(1, beat.grace);
  return Math.max(0, Math.min(1, (g - off) / (2 * g)));
}

function ProgressRing({ size = 40, stroke = 2.6, progress, color, track, children }) {
  const r = (size - stroke) / 2;
  const c = 2 * Math.PI * r;
  return (
    <div style={{ position: 'relative', width: size, height: size, flexShrink: 0 }}>
      <svg width={size} height={size} style={{ position: 'absolute', inset: 0, transform: 'rotate(-90deg)' }}>
        <circle cx={size / 2} cy={size / 2} r={r} fill="none" stroke={track} strokeWidth={stroke} />
        <circle cx={size / 2} cy={size / 2} r={r} fill="none" stroke={color} strokeWidth={stroke}
          strokeLinecap="round" strokeDasharray={c} strokeDashoffset={c * (1 - progress)}
          style={{ transition: 'stroke-dashoffset .4s' }} />
      </svg>
      <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>{children}</div>
    </div>
  );
}

function DueChip({ u, t }) {
  if (u.snoozed) return <Chip color={t.label2} bg={t.fill}><Icon name="snooze" size={12} strokeWidth={2} color={t.label2} />{u.label}</Chip>;
  const color = t.tier[u.tier];
  if (u.tier === 'later') return <Chip color={t.label2} bg={t.fill}>{u.label}</Chip>;
  const solid = u.tier === 'due' || u.tier === 'late';
  return <Chip color={solid ? '#fff' : color} bg={solid ? color : hexA(color, t.dark ? 0.22 : 0.13)}>{u.label}</Chip>;
}

function CheckCircle({ color, onClick, size = 26 }) {
  const t = useTheme();
  return (
    <button onClick={(e) => { e.stopPropagation(); onClick && onClick(); }} style={{
      width: size, height: size, borderRadius: size, border: `2px solid ${color || t.label3}`,
      background: 'none', cursor: 'pointer', padding: 0, flexShrink: 0,
      display: 'flex', alignItems: 'center', justifyContent: 'center',
    }} />
  );
}

// ── Swipe wrapper ──
function SwipeRow({ children, onComplete, trailing = [], theme, disabled }) {
  const t = theme;
  const [dx, setDx] = useState(0);
  const [open, setOpen] = useState(false); // trailing menu open
  const st = useRef({ x: 0, y: 0, drag: false, lock: null, base: 0, moved: false });
  const TRAIL_W = trailing.length * 78;

  const down = (e) => {
    if (disabled) return;
    const p = e.touches ? e.touches[0] : e;
    st.current = { x: p.clientX, y: p.clientY, drag: true, lock: null, base: open ? -TRAIL_W : 0, moved: false };
  };
  const move = (e) => {
    if (!st.current.drag) return;
    const p = e.touches ? e.touches[0] : e;
    const ddx = p.clientX - st.current.x, ddy = p.clientY - st.current.y;
    if (st.current.lock === null) {
      if (Math.abs(ddx) > 8 || Math.abs(ddy) > 8) st.current.lock = Math.abs(ddx) > Math.abs(ddy) ? 'h' : 'v';
    }
    if (st.current.lock !== 'h') return;
    if (Math.abs(ddx) > 4) st.current.moved = true;
    if (e.cancelable) e.preventDefault();
    let nx = st.current.base + ddx;
    if (nx > 0) nx = Math.min(nx, 130) * (nx > 130 ? 1 : 1);
    if (nx < -TRAIL_W - 50) nx = -TRAIL_W - (nx + TRAIL_W) * -0.3;
    setDx(nx);
  };
  const up = () => {
    if (!st.current.drag) return;
    st.current.drag = false;
    const x = dx;
    if (x > 105 && onComplete) { setDx(420); setTimeout(() => { onComplete(); setDx(0); setOpen(false); }, 220); return; }
    if (x < -TRAIL_W * 0.55 && trailing.length) { setDx(-TRAIL_W); setOpen(true); }
    else { setDx(0); setOpen(false); }
  };
  const closeMenu = () => { setDx(0); setOpen(false); };

  const completeReveal = Math.max(0, dx);
  return (
    <div style={{ position: 'relative', overflow: 'hidden' }}>
      {/* complete (leading) bg — only as wide as the right-swipe */}
      <div style={{ position: 'absolute', left: 0, top: 0, bottom: 0, width: Math.max(0, dx), background: t.green, display: 'flex', alignItems: 'center', paddingLeft: 22, overflow: 'hidden' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 7, color: '#fff', whiteSpace: 'nowrap', opacity: completeReveal > 30 ? 1 : 0, transition: 'opacity .1s' }}>
          <Icon name="check" size={22} strokeWidth={2.6} color="#fff" />
          <span style={{ fontFamily: SF, fontSize: 16, fontWeight: 600 }}>Complete</span>
        </div>
      </div>
      {/* trailing actions — innermost color fills any over-swipe */}
      <div style={{ position: 'absolute', top: 0, bottom: 0, right: 0, display: 'flex', justifyContent: 'flex-end', width: Math.max(TRAIL_W, -dx), background: trailing.length ? trailing[0].color : 'transparent' }}>
        {trailing.map((a, i) => (
          <button key={i} onClick={() => { closeMenu(); a.onClick && a.onClick(); }} style={{
            width: 78, border: 'none', cursor: 'pointer', background: a.color, color: '#fff',
            display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 4,
            fontFamily: SF, fontSize: 12.5, fontWeight: 500,
          }}><Icon name={a.icon} size={22} strokeWidth={2} color="#fff" />{a.label}</button>
        ))}
      </div>
      {/* foreground */}
      <div
        onPointerDown={down} onPointerMove={move} onPointerUp={up} onPointerCancel={up}
        onClickCapture={(e) => {
          if (st.current.moved || open) {
            e.stopPropagation(); e.preventDefault();
            if (open && !st.current.moved) closeMenu();
            st.current.moved = false;
          }
        }}
        style={{
          position: 'relative', transform: `translateX(${dx}px)`,
          transition: st.current.drag ? 'none' : 'transform .32s cubic-bezier(.32,.72,0,1)',
          touchAction: 'pan-y',
        }}>{children}</div>
    </div>
  );
}

// ── Beat row ──
function BeatRow({ beat, cadence, urgencyStyle = 'bar', actionStyle = 'swipe', onOpen, onComplete, onSnooze, onSkip, last }) {
  const t = useTheme();
  const u = urgencyOf(beat);
  const tierColor = t.tier[u.tier];
  const isUrgent = u.tier !== 'later';

  // subtitle context
  const snoozed = u.snoozed;
  const desc = (beat.desc || '').trim();
  const hasSub = !!desc || snoozed;

  const tint = urgencyStyle === 'tint' && (u.tier === 'overdue' || u.tier === 'late')
    ? hexA(tierColor, t.dark ? 0.16 : 0.07) : null;
  const rowBg = tint ? `linear-gradient(${tint}, ${tint}), ${t.card}` : t.card;

  const glyph = (
    urgencyStyle === 'ring' && isUrgent ? (
      <ProgressRing size={42} stroke={2.6} progress={urgencyWindow(beat)} color={tierColor} track={t.fill}>
        <GlyphTile glyph={beat.glyph} color={beat.color} size={31} />
      </ProgressRing>
    ) : <GlyphTile glyph={beat.glyph} color={beat.color} size={31} />
  );

  const content = (
    <div onClick={() => { if (actionStyle === 'sheet') onOpen('actions'); else onOpen('detail'); }}
      style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '0 16px', minHeight: hasSub ? 64 : 56, background: rowBg, cursor: 'pointer', position: 'relative' }}>
      {/* leading bar */}
      {urgencyStyle === 'bar' && (
        <div style={{ position: 'absolute', left: 0, top: 10, bottom: 10, width: 4, borderRadius: 4, background: isUrgent ? tierColor : 'transparent' }} />
      )}
      {/* buttons-style check */}
      {actionStyle === 'buttons' && (
        <CheckCircle color={isUrgent ? tierColor : t.label3} onClick={onComplete} />
      )}
      {glyph}
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontFamily: SF, fontSize: 16.5, fontWeight: 600, color: t.label, letterSpacing: -0.2, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{beat.name}</div>
        {desc && <div style={{ fontFamily: SF, fontSize: 13, color: t.label2, marginTop: 2, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{desc}</div>}
        {snoozed && <div style={{ display: 'flex', alignItems: 'center', gap: 5, marginTop: 2 }}>
          <Icon name="snooze" size={12} strokeWidth={2} color={t.orange} />
          <span style={{ fontFamily: SF, fontSize: 12.5, color: t.orange, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>Originally due {window.RhythmData.fmtRelative(beat.due)}</span>
        </div>}
      </div>
      <DueChip u={u} t={t} />
      {!last && <div style={{ position: 'absolute', left: 58, right: 0, bottom: 0, height: 0.5, background: t.sep }} />}
    </div>
  );

  if (actionStyle === 'swipe') {
    return (
      <SwipeRow theme={t} onComplete={onComplete} trailing={[
        { label: 'Skip', icon: 'skip', color: t.dark ? '#48484A' : '#8E8E93', onClick: onSkip },
        { label: 'Snooze', icon: 'snooze', color: t.orange, onClick: onSnooze },
      ]}>{content}</SwipeRow>
    );
  }
  return content;
}

Object.assign(window, { BeatRow, ProgressRing, DueChip, CheckCircle, SwipeRow, urgencyWindow });
