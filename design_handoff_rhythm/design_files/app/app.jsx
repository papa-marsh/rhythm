// app.jsx — RhythmApp (one phone instance) + Root (two phones + tweaks)

const { useState: uS, useEffect: uE } = React;
const RD = window.RhythmData;

function makeBeat(cad, due) {
  return { id: RD.uid('beat'), kind: 'beat', cadenceId: cad.id, name: cad.name, color: cad.color,
    glyph: cad.glyph, status: 'active', due, grace: cad.grace, desc: cad.desc, schedule: cad.schedule, notify: null };
}
function seedState() {
  return {
    cadences: RD.SEED_CADENCES.map(c => ({ ...c, beat: RD.activeBeatFor(c) })),
    standalone: RD.SEED_STANDALONE.map(b => ({ ...b })),
    discoveries: RD.SEED_DISCOVERIES.map(d => ({ ...d, logs: [...d.logs] })),
  };
}

// horizontal push layer
function PushView({ open, children, dark }) {
  const [mounted, setMounted] = uS(open);
  const [shown, setShown] = uS(false);
  uE(() => {
    let raf, to;
    if (open) { setMounted(true); raf = requestAnimationFrame(() => requestAnimationFrame(() => setShown(true))); }
    else { setShown(false); to = setTimeout(() => setMounted(false), 320); }
    return () => { cancelAnimationFrame(raf); clearTimeout(to); };
  }, [open]);
  if (!mounted) return null;
  return (
    <div style={{
      position: 'absolute', inset: 0, zIndex: 60, background: dark ? '#000' : '#F2F2F7',
      transform: shown ? 'translateX(0)' : 'translateX(100%)',
      transition: 'transform .34s cubic-bezier(.32,.72,0,1)',
      boxShadow: shown ? '-12px 0 30px rgba(0,0,0,0.12)' : 'none',
    }}>{children}</div>
  );
}

function Toast({ toast }) {
  const t = useTheme();
  if (!toast) return null;
  return (
    <div style={{
      position: 'absolute', left: 0, right: 0, bottom: TABBAR_H + 12, zIndex: 150,
      display: 'flex', justifyContent: 'center', pointerEvents: 'none',
      animation: 'rhythmToast .25s ease',
    }}>
      <div style={{
        display: 'flex', alignItems: 'center', gap: 9, padding: '11px 16px', borderRadius: 14,
        background: t.dark ? 'rgba(58,58,60,0.96)' : 'rgba(40,40,42,0.96)',
        backdropFilter: 'blur(20px)', WebkitBackdropFilter: 'blur(20px)', boxShadow: '0 8px 24px rgba(0,0,0,0.3)',
      }}>
        <Icon name={toast.icon || 'check'} size={18} strokeWidth={2.4} color={toast.color || '#34C759'} />
        <span style={{ fontFamily: SF, fontSize: 14.5, fontWeight: 500, color: '#fff' }}>{toast.msg}</span>
      </div>
    </div>
  );
}

function RhythmApp({ baseAppearance, tw }) {
  const [st, setSt] = uS(seedState);
  const [appearance, setAppearance] = uS('system');
  const [settings, setSettings] = uS({
    defaultSchedule: 'completion', notify: { almost: false, due: true, overdue: true, time: '9:00 AM' },
    sound: true, vibrate: true, showEmoji: true,
  });
  const [tab, setTab] = uS('today');
  const [detailCad, setDetailCad] = uS(null);
  const [toast, setToast] = uS(null);
  const toastTimer = React.useRef(null);
  const flash = (msg, icon, color) => {
    setToast({ msg, icon, color }); clearTimeout(toastTimer.current);
    toastTimer.current = setTimeout(() => setToast(null), 2200);
  };

  // sheets
  const [addMenu, setAddMenu] = uS(false);
  const [createCad, setCreateCad] = uS({ open: false, mode: 'single', initial: null });
  const editId = React.useRef(null);
  const [createBeat, setCreateBeat] = uS(false);
  const [createDisc, setCreateDisc] = uS(false);
  const [convert, setConvert] = uS({ open: false, disc: null, suggested: 30 });
  const [beatDetail, setBeatDetail] = uS({ open: false, beat: null });
  const [beatActions, setBeatActions] = uS({ open: false, beat: null });
  const [snooze, setSnooze] = uS({ open: false, beat: null });
  const [cadSort, setCadSort] = uS('az');
  const [sortOpen, setSortOpen] = uS(false);

  const resolved = appearance === 'system' ? baseAppearance : appearance;
  const theme = makeTheme(resolved, tw.accent, settings.showEmoji !== false);

  const getCadence = (id) => st.cadences.find(c => c.id === id);

  // ── beat mutations ──
  const updateBeat = (beat, patch) => {
    setSt(s => {
      if (beat.cadenceId) return { ...s, cadences: s.cadences.map(c => c.id === beat.cadenceId ? { ...c, beat: { ...c.beat, ...patch } } : c) };
      return { ...s, standalone: s.standalone.map(b => b.id === beat.id ? { ...b, ...patch } : b) };
    });
  };
  const advance = (beat, action) => {
    setSt(s => {
      if (beat.cadenceId) {
        return {
          ...s, cadences: s.cadences.map(c => {
            if (c.id !== beat.cadenceId) return c;
            const nextDue = c.schedule === 'completion'
              ? RD.addEvery(RD.TODAY, c.every, RD.TODAY.getDate())
              : RD.addEvery(c.beat.due, c.every, c.anchorDay);
            const hist = [{ date: RD.TODAY, action }, ...c.history];
            return { ...c, history: hist, beat: makeBeat(c, nextDue) };
          }),
        };
      }
      return { ...s, standalone: s.standalone.filter(b => b.id !== beat.id) };
    });
  };
  const completeBeat = (beat) => { advance(beat, 'completed'); flash(beat.cadenceId ? 'Completed · next beat scheduled' : 'Completed', 'check', '#30D158'); };
  const skipBeat = (beat) => { advance(beat, 'skipped'); flash('Skipped', 'skip', '#FF9F0A'); };
  const doSnooze = (beat, date) => { updateBeat(beat, { snoozedUntil: date }); flash(`Snoozed until ${RD.fmtDate(date)}`, 'snooze', '#FF9F0A'); };
  const unsnooze = (beat) => updateBeat(beat, { snoozedUntil: null });
  const saveBeat = (draft) => updateBeat(draft, { name: draft.name, due: draft.due, grace: draft.grace, notify: draft.notify, desc: draft.desc, snoozedUntil: draft.snoozedUntil });
  const deleteBeat = (beat) => { setSt(s => ({ ...s, standalone: s.standalone.filter(b => b.id !== beat.id) })); flash('Beat deleted', 'trash2', '#FF453A'); };

  // ── cadence mutations ──
  const addCadence = (obj, editing) => {
    setSt(s => {
      if (editing && editId.current) {
        return { ...s, cadences: s.cadences.map(c => c.id === editId.current ? { ...c, ...obj, anchorDay: (obj.firstDue || c.beat.due).getDate(), beat: { ...c.beat, name: obj.name, color: obj.color, glyph: obj.glyph, grace: obj.grace, schedule: obj.schedule, due: obj.firstDue || c.beat.due } } : c) };
      }
      const cad = RD.cadence({ ...obj });
      cad.beat = makeBeat(cad, obj.firstDue || RD.dateFromOffset(obj.freq));
      cad.history = [];
      return { ...s, cadences: [...s.cadences, cad] };
    });
    flash(editing ? 'Cadence updated' : 'Cadence created', 'repeat', tw.accent);
  };
  const deleteCadence = (c) => { setDetailCad(null); setSt(s => ({ ...s, cadences: s.cadences.filter(x => x.id !== c.id) })); flash('Cadence deleted', 'trash2', '#FF453A'); };

  // ── discovery mutations ──
  const logDiscovery = (disc) => { setSt(s => ({ ...s, discoveries: s.discoveries.map(d => d.id === disc.id ? { ...d, logs: [...d.logs, RD.TODAY] } : d) })); flash('Occurrence logged', 'target', tw.accent); };
  const addDiscovery = (d, logToday) => { setSt(s => ({ ...s, discoveries: [...s.discoveries, { id: RD.uid('disc'), kind: 'discovery', name: d.name, color: d.color, glyph: d.glyph, logs: logToday ? [RD.TODAY] : [], desc: '' }] })); flash('Discovery started', 'target', tw.accent); };
  const convertDiscovery = (disc, cadObj) => {
    setSt(s => {
      const cad = RD.cadence({ ...cadObj });
      cad.beat = makeBeat(cad, cadObj.firstDue || RD.dateFromOffset(cadObj.freq)); cad.history = [];
      return { ...s, discoveries: s.discoveries.filter(d => d.id !== disc.id), cadences: [...s.cadences, cad] };
    });
    flash('Converted to cadence', 'sparkles', '#30D158');
  };
  const addBeat = (d) => { setSt(s => ({ ...s, standalone: [...s.standalone, RD.beat({ name: d.name, color: d.color, glyph: d.glyph, dueOff: RD.daysBetween(RD.TODAY, d.due), grace: d.grace })] })); flash('Beat added', 'flag', tw.accent); };

  // open beat (detail or actions)
  const openBeat = (beat, mode) => { if (mode === 'actions') setBeatActions({ open: true, beat }); else setBeatDetail({ open: true, beat }); };
  const openCadence = (c) => { setTab('cadences'); setDetailCad(c.id); };

  const handlers = {
    open: openBeat, complete: completeBeat, skip: skipBeat,
    snooze: (b) => setSnooze({ open: true, beat: b }), unsnooze, deleteCadence,
  };

  // active beats (snoozed shown inline with indicator, sorted by effective due)
  const allBeats = [...st.cadences.map(c => c.beat), ...st.standalone].filter(b => b.status !== 'done');

  const detailCadObj = detailCad ? getCadence(detailCad) : null;
  const beatLive = (b) => b && (b.cadenceId ? (getCadence(b.cadenceId) || {}).beat : st.standalone.find(x => x.id === b.id)) || b;

  return (
    <ThemeCtx.Provider value={theme}>
      <div style={{ position: 'absolute', inset: 0, zIndex: 1, overflow: 'hidden', background: theme.bg }}>
        {/* tab screens */}
        {tab === 'today' && <TodayScreen beats={allBeats} snoozed={[]} getCadence={getCadence} handlers={handlers} tw={tw} onAdd={() => setAddMenu(true)} />}
        {tab === 'cadences' && <CadencesScreen cadences={st.cadences} onAdd={() => setAddMenu(true)} onOpenCadence={(c) => setDetailCad(c.id)} sort={cadSort} onSortMenu={() => setSortOpen(true)} />}
        {tab === 'discovery' && <DiscoveryScreen discoveries={st.discoveries} onLog={logDiscovery} onConvert={(d, sug) => setConvert({ open: true, disc: d, suggested: sug })} onAdd={() => setCreateDisc(true)} />}
        {tab === 'settings' && <SettingsScreen settings={settings} setSettings={setSettings} appearance={appearance} onSetAppearance={setAppearance} />}

        {/* pushed cadence detail */}
        <PushView open={!!detailCad} dark={theme.dark}>
          {detailCadObj && <CadenceDetailScreen cadence={detailCadObj} getCadence={getCadence} handlers={handlers} onBack={() => setDetailCad(null)}
            onEdit={(c) => { editId.current = c.id; setCreateCad({ open: true, mode: 'edit', initial: c }); }} />}
        </PushView>

        <TabBar tab={tab} onTab={(x) => { setTab(x); if (x !== 'cadences') setDetailCad(null); }} />
        <Toast toast={toast} />

        {/* sheets */}
        <AddMenu open={addMenu} onClose={() => setAddMenu(false)}
          onCadence={() => { editId.current = null; setCreateCad({ open: true, mode: tw.createForm, initial: null }); }}
          onBeat={() => setCreateBeat(true)} onDiscovery={() => setCreateDisc(true)} />

        <CreateCadenceSheet open={createCad.open} mode={createCad.mode} initial={createCad.initial}
          onClose={() => setCreateCad(c => ({ ...c, open: false }))} onSubmit={addCadence} />
        <CreateBeatSheet open={createBeat} onClose={() => setCreateBeat(false)} onSubmit={addBeat} />
        <CreateDiscoverySheet open={createDisc} onClose={() => setCreateDisc(false)} onSubmit={addDiscovery} />
        <ConvertDiscoverySheet open={convert.open} disc={convert.disc} suggested={convert.suggested}
          onClose={() => setConvert(c => ({ ...c, open: false }))} onSubmit={convertDiscovery} />

        <BeatDetailSheet open={beatDetail.open} beat={beatLive(beatDetail.beat)} cadence={beatDetail.beat && beatDetail.beat.cadenceId ? getCadence(beatDetail.beat.cadenceId) : null}
          onClose={() => setBeatDetail({ open: false, beat: beatDetail.beat })}
          onComplete={() => completeBeat(beatDetail.beat)} onSkip={() => skipBeat(beatDetail.beat)}
          onSnoozeOpen={() => setSnooze({ open: true, beat: beatDetail.beat })}
          onSave={saveBeat} onDelete={() => deleteBeat(beatDetail.beat)} onOpenCadence={openCadence} />

        <BeatActionSheet open={beatActions.open} beat={beatActions.beat}
          onClose={() => setBeatActions({ open: false, beat: beatActions.beat })}
          onComplete={() => completeBeat(beatActions.beat)}
          onSnooze={() => setSnooze({ open: true, beat: beatActions.beat })}
          onSkip={() => skipBeat(beatActions.beat)}
          onEdit={() => setBeatDetail({ open: true, beat: beatActions.beat })} />

        <SnoozeSheet open={snooze.open} beat={beatLive(snooze.beat)} onClose={() => setSnooze({ open: false, beat: snooze.beat })}
          onPick={(date) => doSnooze(snooze.beat, date)} />

        <ActionSheet open={sortOpen} onClose={() => setSortOpen(false)} title="SORT CADENCES" actions={[
          { label: 'Name (A–Z)', icon: cadSort === 'az' ? 'check' : undefined, onClick: () => setCadSort('az') },
          { label: 'Frequency', icon: cadSort === 'freq' ? 'check' : undefined, onClick: () => setCadSort('freq') },
          { label: 'Recently added', icon: cadSort === 'created' ? 'check' : undefined, onClick: () => setCadSort('created') },
        ]} />
      </div>
    </ThemeCtx.Provider>
  );
}

// ── Root: two phones + tweaks ──
const TWEAK_DEFAULTS = /*EDITMODE-BEGIN*/{
  "accent": "#0A84FF",
  "urgencyStyle": "bar",
  "beatActions": "swipe",
  "createForm": "single",
  "view": "both"
}/*EDITMODE-END*/;

function PhoneLabel({ children }) {
  return <div style={{ fontFamily: SF, fontSize: 13, fontWeight: 600, color: '#8A8A8E', letterSpacing: 0.3, textTransform: 'uppercase', textAlign: 'center', marginBottom: 14 }}>{children}</div>;
}

function Root() {
  const [t, setTweak] = useTweaks(TWEAK_DEFAULTS);
  // Design locked: Bar urgency · Swipe actions · Single create form · Blue accent.
  const ACCENT = '#0A84FF';
  const tw = { accent: ACCENT, urgencyStyle: 'bar', beatActions: 'swipe', createForm: 'single' };
  const showLight = t.view !== 'dark';
  const showDark = t.view !== 'light';

  const phone = (appe, label) => (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
      <PhoneLabel>{label}</PhoneLabel>
      <IOSDevice dark={appe === 'dark'}>
        <RhythmApp baseAppearance={appe} tw={tw} />
      </IOSDevice>
    </div>
  );

  return (
    <div style={{ minHeight: '100vh', width: '100%', background: 'radial-gradient(120% 120% at 50% 0%, #ECECEF 0%, #DEDEE3 60%, #D2D2D8 100%)', padding: '40px 24px 64px', boxSizing: 'border-box' }}>
      <div style={{ textAlign: 'center', marginBottom: 30 }}>
        <div style={{ display: 'inline-flex', alignItems: 'center', gap: 11 }}>
          <div style={{ width: 40, height: 40, borderRadius: 11, background: ACCENT, display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: `0 4px 14px ${ACCENT}55` }}>
            <Icon name="cadences" size={24} strokeWidth={2.1} color="#fff" />
          </div>
          <span style={{ fontFamily: SF, fontSize: 30, fontWeight: 800, letterSpacing: -0.5, color: '#1C1C1E' }}>Rhythm</span>
        </div>
        <div style={{ fontFamily: SF, fontSize: 15, color: '#6A6A6E', marginTop: 8, maxWidth: 520, marginLeft: 'auto', marginRight: 'auto', lineHeight: '21px' }}>
          A self-populating to-do list for recurring life. Cadences generate beats; grace periods decide when they matter. Try swiping a beat, opening one, or creating a cadence.
        </div>
      </div>
      <div style={{ display: 'flex', gap: 48, justifyContent: 'center', alignItems: 'flex-start', flexWrap: 'wrap' }}>
        {showLight && phone('light', 'Light')}
        {showDark && phone('dark', 'Dark')}
      </div>

      <TweaksPanel>
        <TweakSection label="Preview" />
        <TweakRadio label="Show" value={t.view} options={[{ value: 'both', label: 'Both' }, { value: 'light', label: 'Light' }, { value: 'dark', label: 'Dark' }]} onChange={v => setTweak('view', v)} />
      </TweaksPanel>
    </div>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<Root />);
