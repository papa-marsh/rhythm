// screens.jsx — Today, Cadences, Cadence detail
// Exports: TodayScreen, CadencesScreen, CadenceDetailScreen

const SC = window.RhythmData;

function PlusBtn({ onClick }) {
  const t = useTheme();
  return (
    <button onClick={onClick} style={{ border: 'none', background: 'none', cursor: 'pointer', padding: 6, display: 'flex' }}>
      <Icon name="plus" size={24} strokeWidth={2.4} color={t.accent} />
    </button>
  );
}

function SummaryStrip({ beats }) {
  const t = useTheme();
  const counts = { attention: 0, radar: 0 };
  beats.forEach(b => { const r = SC.urgencyOf(b).rank; if (r >= 3) counts.attention++; else if (r >= 1) counts.radar++; });
  const parts = [];
  if (counts.attention) parts.push({ c: t.red, n: counts.attention, l: 'overdue' });
  if (counts.radar) parts.push({ c: t.accent, n: counts.radar, l: 'upcoming' });
  if (!parts.length) return null;
  return (
    <div style={{ display: 'flex', gap: 16, padding: '2px 22px 4px' }}>
      {parts.map((p, i) => (
        <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 7 }}>
          <span style={{ width: 8, height: 8, borderRadius: 8, background: p.c }} />
          <span style={{ fontFamily: SF, fontSize: 13.5, color: t.label2 }}><b style={{ color: t.label, fontWeight: 600 }}>{p.n}</b> {p.l}</span>
        </div>
      ))}
    </div>
  );
}

function beatRowProps(b, getCadence, handlers, tw) {
  return {
    beat: b, cadence: b.cadenceId ? getCadence(b.cadenceId) : null,
    urgencyStyle: tw.urgencyStyle, actionStyle: tw.beatActions,
    onOpen: (mode) => handlers.open(b, mode),
    onComplete: () => handlers.complete(b),
    onSnooze: () => handlers.snooze(b),
    onSkip: () => handlers.skip(b),
  };
}

function TodayScreen({ beats, snoozed, getCadence, handlers, tw, onAdd }) {
  const t = useTheme();
  const [q, setQ] = useState('');
  const filtered = q.trim() ? beats.filter(b => b.name.toLowerCase().includes(q.toLowerCase()) || (b.desc || '').toLowerCase().includes(q.toLowerCase())) : beats;
  const active = filtered.filter(b => SC.urgencyOf(b).rank >= 1).sort((a, b) => {
    const ua = SC.urgencyOf(a), ub = SC.urgencyOf(b);
    return ub.rank - ua.rank || ua.off - ub.off;
  });
  const later = filtered.filter(b => SC.urgencyOf(b).rank === 0).sort((a, b) => SC.urgencyOf(a).off - SC.urgencyOf(b).off);
  const wd = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'][SC.TODAY.getDay()];

  return (
    <ScreenScaffold title="Today" subtitle={`${wd}, ${SC.MONTHS[SC.TODAY.getMonth()]} ${SC.TODAY.getDate()}`}
      search={q} onSearch={setQ} searchPlaceholder="Search beats"
      trailing={<PlusBtn onClick={onAdd} />}>
      <div style={{ height: 2 }} />
      <SummaryStrip beats={beats} />

      {active.length > 0 ? (
        <Section first>
          {active.map((b, i) => <BeatRow key={b.id} {...beatRowProps(b, getCadence, handlers, tw)} last={i === active.length - 1} />)}
        </Section>
      ) : (
        <div style={{ textAlign: 'center', padding: '54px 30px' }}>
          <div style={{ width: 64, height: 64, borderRadius: 64, background: hexA(t.green, t.dark ? 0.2 : 0.12), display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto 16px' }}>
            <Icon name="check" size={34} strokeWidth={2.4} color={t.green} />
          </div>
          <div style={{ fontFamily: SF, fontSize: 19, fontWeight: 700, color: t.label }}>All caught up</div>
          <div style={{ fontFamily: SF, fontSize: 14.5, color: t.label2, marginTop: 5, lineHeight: '20px' }}>Nothing’s within its grace period.<br />Enjoy the quiet.</div>
        </div>
      )}

      {later.length > 0 && (
        <Section header="Later">
          {later.map((b, i) => <BeatRow key={b.id} {...beatRowProps(b, getCadence, handlers, tw)} last={i === later.length - 1} />)}
        </Section>
      )}
      <div style={{ height: 10 }} />
    </ScreenScaffold>
  );
}

function CadencesScreen({ cadences, onAdd, onOpenCadence, sort, onSortMenu }) {
  const t = useTheme();
  const [q, setQ] = useState('');
  let list = [...cadences];
  if (q.trim()) { const s = q.toLowerCase(); list = list.filter(c => c.name.toLowerCase().includes(s) || (c.desc || '').toLowerCase().includes(s)); }
  list.sort((a, b) => sort === 'freq' ? a.freq - b.freq : sort === 'created' ? b.created - a.created : a.name.localeCompare(b.name));
  return (
    <ScreenScaffold title="Cadences" subtitle={`${cadences.length} recurring`}
      search={q} onSearch={setQ} searchPlaceholder="Search cadences"
      trailing={<div style={{ display: 'flex', alignItems: 'center', gap: 2 }}>
        <button onClick={onSortMenu} style={{ border: 'none', background: 'none', cursor: 'pointer', padding: 6, display: 'flex' }}><Icon name="sort" size={22} strokeWidth={1.9} color={t.accent} /></button>
        <PlusBtn onClick={onAdd} />
      </div>}>
      <Section first>
        {list.map((c, i) => {
          const fixed = c.schedule === 'dueDate';
          return (
            <Row key={c.id} left={<GlyphTile glyph={c.glyph} color={c.color} size={31} />}
              title={c.name} titleWeight={600} subtitle={c.desc || undefined}
              accessory={<div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <Chip color={t.label2} bg={t.fill}><Icon name={fixed ? 'anchor' : 'repeat'} size={12} strokeWidth={2} color={t.label2} />{SC.shortEvery(c.every)}</Chip>
                <Icon name="chevron" size={15} strokeWidth={2.4} color={t.label3} />
              </div>}
              onClick={() => onOpenCadence(c)} last={i === list.length - 1} height={c.desc ? 62 : 54} />
          );
        })}
        {list.length === 0 && <div style={{ padding: '30px', textAlign: 'center', fontFamily: SF, color: t.label2, fontSize: 14.5 }}>No matches</div>}
      </Section>
      <div style={{ height: 10 }} />
    </ScreenScaffold>
  );
}

function StatCard({ value, label, color }) {
  const t = useTheme();
  return (
    <div style={{ flex: 1, background: t.card, borderRadius: 12, padding: '13px 14px' }}>
      <div style={{ fontFamily: SF, fontSize: 22, fontWeight: 700, color: color || t.label, letterSpacing: -0.4 }}>{value}</div>
      <div style={{ fontFamily: SF, fontSize: 12.5, color: t.label2, marginTop: 2 }}>{label}</div>
    </div>
  );
}

function CadenceDetailScreen({ cadence, getCadence, handlers, onBack, onEdit }) {
  const t = useTheme();
  const c = cadence;
  const u = SC.urgencyOf(c.beat);
  // avg interval from history
  const hist = c.history;
  let avg = c.freq;
  if (hist.length >= 2) {
    let sum = 0; for (let i = 0; i < hist.length - 1; i++) sum += SC.daysBetween(hist[i + 1].date, hist[i].date);
    avg = Math.round(sum / (hist.length - 1));
  }
  return (
    <ScreenScaffold title={c.name} big={false}
      leading={<NavBtn onClick={onBack}><Icon name="back" size={20} strokeWidth={2.6} color={t.accent} style={{ marginRight: -2 }} />Cadences</NavBtn>}
      trailing={<NavBtn onClick={() => onEdit(c)}>Edit</NavBtn>}>

      {/* hero */}
      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', padding: '16px 20px 16px', gap: 10 }}>
        <GlyphTile glyph={c.glyph} color={c.color} size={62} radius={17} />
        <div style={{ fontFamily: SF, fontSize: 22, fontWeight: 700, color: t.label, textAlign: 'center', letterSpacing: -0.3 }}>{c.name}</div>
        {c.desc && <div style={{ fontFamily: SF, fontSize: 14.5, color: t.label2, textAlign: 'center', lineHeight: '20px', maxWidth: 300 }}>{c.desc}</div>}
      </div>

      {/* next beat */}
      <Section header="Next beat">
        <div style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '12px 16px' }}>
          <div style={{ flex: 1 }}>
            <div style={{ fontFamily: SF, fontSize: 17, fontWeight: 600, color: t.label }}>{SC.fmtDate(c.beat.due, { absolute: true })}</div>
            <div style={{ fontFamily: SF, fontSize: 13.5, color: t.label2, marginTop: 2 }}>{SC.fmtWeekday(c.beat.due)} · {SC.fmtRelative(c.beat.due)}</div>
          </div>
          <DueChip u={u} t={t} />
        </div>
        <div style={{ height: 0.5, background: t.sep, marginLeft: 16 }} />
        <div style={{ padding: '12px 16px', display: 'flex', gap: 10 }}>
          <BigButton icon="check" onClick={() => handlers.complete(c.beat)}>Complete</BigButton>
          <div style={{ width: 130 }}><BigButton kind="tinted" icon="snooze" onClick={() => handlers.snooze(c.beat)}>Snooze</BigButton></div>
        </div>
      </Section>

      {/* stats */}
      <div style={{ display: 'flex', gap: 10, margin: '26px 16px 0' }}>
        <StatCard value={SC.shortEvery(c.every)} label="Target interval" />
        <StatCard value={`${avg}d`} label="Actual average" color={Math.abs(avg - c.freq) > c.grace ? t.orange : t.green} />
        <StatCard value={`${c.grace}d`} label="Grace period" />
      </div>

      {/* schedule */}
      <Section header="Schedule">
        <Row title="Scheduling" value={c.schedule === 'completion' ? 'Relative' : 'Fixed'} accessory="none" />
        <Row title="Frequency" value={(() => { const h = SC.humanEvery(c.every); return h.charAt(0).toUpperCase() + h.slice(1); })()} accessory="none" />
        <Row title="Notifications" value={[c.notify.almost && 'Almost', c.notify.due && 'Due', c.notify.overdue && 'Overdue'].filter(Boolean).join(', ') || 'Off'} accessory="none" last />
      </Section>

      {/* history */}
      <Section header={`History · ${hist.length} beats`}>
        {hist.map((h, i) => {
          const interval = i < hist.length - 1 ? SC.daysBetween(hist[i + 1].date, h.date) : null;
          return (
            <Row key={i} left={<div style={{ width: 30, display: 'flex', justifyContent: 'center' }}>
              <span style={{ width: 11, height: 11, borderRadius: 11, border: `2px solid ${h.action === 'skipped' ? t.label3 : t.green}`, background: h.action === 'skipped' ? 'transparent' : t.green }} />
            </div>}
              title={SC.fmtDate(h.date, { absolute: true })}
              subtitle={SC.fmtWeekday(h.date) + (h.action === 'skipped' ? ' · skipped' : ' · completed')}
              value={interval != null ? `${interval}d` : null} accessory="none" last={i === hist.length - 1} />
          );
        })}
      </Section>

      <div style={{ padding: '24px 16px 8px' }}>
        <BigButton kind="tinted" danger icon="trash2" onClick={() => handlers.deleteCadence(c)}>Delete cadence</BigButton>
      </div>
      <div style={{ height: 16 }} />
    </ScreenScaffold>
  );
}

Object.assign(window, { TodayScreen, CadencesScreen, CadenceDetailScreen, PlusBtn, StatCard });
