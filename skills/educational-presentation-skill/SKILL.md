---
name: educational-presentation
description: Crea presentazioni interattive per lezioni scolastiche ITIS usando React via CDN, dark theme, simulatori interattivi, e quiz. Due approcci consolidati: CDN-based (zero build, HTML puri) e Build-based (Vite+TS+Tailwind). Deploy su GitHub Pages. Progetto di riferimento: presentazione-vpn (Mar 2026).
---

# Educational Presentation Skill

## Quando usare questa skill
- Creare una nuova presentazione interattiva per lezioni scolastiche ITIS
- Aggiungere moduli/slide a una presentazione esistente
- Creare un gioco educativo multiplayer (escape room)
- Scegliere tra approccio CDN (rapido) o Build (scalabile)
- Creare simulatori interattivi (ACL, packet filter, handshake, configuratori)
- Creare quiz interattivi con feedback immediato
- Deploy su GitHub Pages

## Stack Standard

Tutte le presentazioni seguono lo stesso stack leggero:

```
presentazione-ARGOMENTO/
├── index.html              # Entry point + dashboard
├── modulo1.html            # Slide modulo 1
├── modulo2.html            # Slide modulo 2
├── ...
├── quiz.html               # Quiz interattivo
├── package.json            # Solo per dev server locale (opzionale)
└── .github/
    └── workflows/
        └── deploy.yml      # Auto-deploy GitHub Pages
```

### Dipendenze (tutte via CDN, zero build)

```html
<!-- React 18 via CDN -->
<script crossorigin src="https://unpkg.com/react@18/umd/react.production.min.js"></script>
<script crossorigin src="https://unpkg.com/react-dom@18/umd/react-dom.production.min.js"></script>
<script src="https://unpkg.com/@babel/standalone/babel.min.js"></script>

<!-- Icone -->
<script src="https://unpkg.com/lucide-react@latest/dist/umd/lucide-react.min.js"></script>

<!-- Font -->
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap" rel="stylesheet">
```

## Design System

### Tema Dark Standard

```css
:root {
    --bg-primary: #0f172a;      /* Sfondo principale */
    --bg-secondary: #1e293b;    /* Card, box */
    --bg-tertiary: #334155;     /* Hover, bordi */
    --text-primary: #f1f5f9;    /* Testo principale */
    --text-secondary: #94a3b8;  /* Testo secondario */
    --accent-blue: #3b82f6;     /* Accent primario */
    --accent-green: #10b981;    /* Successo, conferma */
    --accent-orange: #f59e0b;   /* Warning, evidenziazione */
    --accent-red: #ef4444;      /* Errore, pericolo */
    --accent-purple: #8b5cf6;   /* Secondario */
}

body {
    font-family: 'Inter', sans-serif;
    background: var(--bg-primary);
    color: var(--text-primary);
    margin: 0;
    padding: 0;
}
```

### Colori per Modulo

```javascript
const moduleColors = {
    1: '#3b82f6',  // Blu — Fondamenti
    2: '#10b981',  // Verde — Concetti base
    3: '#f59e0b',  // Arancione — Intermedio
    4: '#ef4444',  // Rosso — Avanzato
    5: '#8b5cf6',  // Viola — Pratico
    6: '#06b6d4',  // Ciano — Quiz/Recap
};
```

## Template Slide

### Slide Base con Navigazione

```html
<script type="text/babel">
const { useState, useEffect } = React;
const { ChevronLeft, ChevronRight, Home } = lucideReact;

const slides = [
    {
        title: "Titolo Slide",
        content: () => (
            <div style={{ padding: '2rem' }}>
                <h2 style={{ color: 'var(--accent-blue)', marginBottom: '1.5rem' }}>
                    Sottotitolo
                </h2>
                <ul style={{ lineHeight: 2, fontSize: '1.1rem' }}>
                    <li><strong>Punto chiave 1</strong> — spiegazione</li>
                    <li><strong>Punto chiave 2</strong> — spiegazione</li>
                </ul>
            </div>
        )
    },
    // ... altre slide
];

function Presentation() {
    const [current, setCurrent] = useState(0);

    // Navigazione tastiera
    useEffect(() => {
        const handler = (e) => {
            if (e.key === 'ArrowRight' || e.key === ' ') setCurrent(c => Math.min(c + 1, slides.length - 1));
            if (e.key === 'ArrowLeft') setCurrent(c => Math.max(c - 1, 0));
            if (e.key === 'Escape') window.location.href = 'index.html';
        };
        window.addEventListener('keydown', handler);
        return () => window.removeEventListener('keydown', handler);
    }, []);

    const slide = slides[current];

    return (
        <div style={{ minHeight: '100vh', display: 'flex', flexDirection: 'column' }}>
            {/* Header */}
            <div style={{
                background: 'var(--bg-secondary)',
                padding: '1rem 2rem',
                display: 'flex',
                justifyContent: 'space-between',
                alignItems: 'center'
            }}>
                <a href="index.html" style={{ color: 'var(--text-secondary)', cursor: 'pointer' }}>
                    <Home size={24} />
                </a>
                <h1 style={{ fontSize: '1.2rem', margin: 0 }}>{slide.title}</h1>
                <span style={{ color: 'var(--text-secondary)' }}>
                    {current + 1} / {slides.length}
                </span>
            </div>

            {/* Content */}
            <div style={{ flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                {slide.content()}
            </div>

            {/* Navigation */}
            <div style={{
                padding: '1rem',
                display: 'flex',
                justifyContent: 'center',
                gap: '1rem'
            }}>
                <button onClick={() => setCurrent(c => Math.max(c - 1, 0))}
                    disabled={current === 0}
                    style={{ background: 'var(--bg-secondary)', border: 'none', color: 'var(--text-primary)', padding: '0.5rem 1rem', borderRadius: '8px', cursor: 'pointer' }}>
                    <ChevronLeft size={20} /> Indietro
                </button>
                <button onClick={() => setCurrent(c => Math.min(c + 1, slides.length - 1))}
                    disabled={current === slides.length - 1}
                    style={{ background: 'var(--accent-blue)', border: 'none', color: 'white', padding: '0.5rem 1rem', borderRadius: '8px', cursor: 'pointer' }}>
                    Avanti <ChevronRight size={20} />
                </button>
            </div>

            {/* Progress bar */}
            <div style={{ height: '4px', background: 'var(--bg-tertiary)' }}>
                <div style={{
                    height: '100%',
                    width: `${((current + 1) / slides.length) * 100}%`,
                    background: 'var(--accent-blue)',
                    transition: 'width 0.3s'
                }} />
            </div>
        </div>
    );
}

ReactDOM.createRoot(document.getElementById('root')).render(<Presentation />);
</script>
```

### Dashboard (index.html)

```html
<!-- Card per ogni modulo -->
<div style={{
    display: 'grid',
    gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))',
    gap: '1.5rem',
    padding: '2rem'
}}>
    {modules.map((mod, i) => (
        <a href={mod.file} key={i} style={{
            background: 'var(--bg-secondary)',
            borderRadius: '12px',
            padding: '1.5rem',
            borderLeft: `4px solid ${moduleColors[i + 1]}`,
            textDecoration: 'none',
            color: 'var(--text-primary)',
            transition: 'transform 0.2s',
        }}>
            <h3 style={{ color: moduleColors[i + 1] }}>Modulo {i + 1}</h3>
            <p style={{ color: 'var(--text-secondary)' }}>{mod.title}</p>
            <span style={{ fontSize: '0.85rem', color: 'var(--text-secondary)' }}>
                {mod.slides} slide
            </span>
        </a>
    ))}
</div>
```

## Template Simulatore Interattivo

```javascript
// Esempio: Simulatore Packet Filter
function PacketFilterSimulator() {
    const [rules, setRules] = useState([
        { action: 'ALLOW', protocol: 'TCP', srcIP: '192.168.1.0/24', dstPort: '80' },
        { action: 'DENY', protocol: '*', srcIP: '*', dstPort: '*' }
    ]);
    const [testPacket, setTestPacket] = useState({ protocol: 'TCP', srcIP: '192.168.1.10', dstPort: '80' });
    const [result, setResult] = useState(null);

    const evaluate = () => {
        for (const rule of rules) {
            if (matchesRule(testPacket, rule)) {
                setResult({ action: rule.action, rule });
                return;
            }
        }
        setResult({ action: 'DENY', rule: 'default' });
    };

    return (
        <div style={{ background: 'var(--bg-secondary)', borderRadius: '12px', padding: '2rem' }}>
            <h3>🔒 Simulatore Packet Filter</h3>
            {/* UI per regole, pacchetto test, e risultato */}
            <button onClick={evaluate} style={{
                background: 'var(--accent-blue)',
                color: 'white',
                border: 'none',
                padding: '0.75rem 1.5rem',
                borderRadius: '8px',
                cursor: 'pointer'
            }}>
                Valuta Pacchetto
            </button>
            {result && (
                <div style={{
                    marginTop: '1rem',
                    padding: '1rem',
                    borderRadius: '8px',
                    background: result.action === 'ALLOW' ? '#10b98133' : '#ef444433',
                    color: result.action === 'ALLOW' ? 'var(--accent-green)' : 'var(--accent-red)'
                }}>
                    {result.action === 'ALLOW' ? '✅ Pacchetto ACCETTATO' : '❌ Pacchetto RIFIUTATO'}
                </div>
            )}
        </div>
    );
}
```

## Template Quiz

```javascript
function Quiz() {
    const questions = [
        {
            question: "Quale porta usa HTTPS?",
            options: ["80", "443", "8080", "22"],
            correct: 1,
            explanation: "HTTPS usa la porta 443, HTTP usa la 80."
        },
        // ...
    ];

    const [current, setCurrent] = useState(0);
    const [score, setScore] = useState(0);
    const [answered, setAnswered] = useState(false);
    const [selected, setSelected] = useState(null);

    const handleAnswer = (idx) => {
        if (answered) return;
        setSelected(idx);
        setAnswered(true);
        if (idx === questions[current].correct) setScore(s => s + 1);
    };

    return (
        <div>
            <h3>Domanda {current + 1}/{questions.length}</h3>
            <p style={{ fontSize: '1.2rem' }}>{questions[current].question}</p>
            {questions[current].options.map((opt, i) => (
                <button key={i} onClick={() => handleAnswer(i)} style={{
                    display: 'block',
                    width: '100%',
                    padding: '1rem',
                    margin: '0.5rem 0',
                    borderRadius: '8px',
                    border: 'none',
                    cursor: answered ? 'default' : 'pointer',
                    background: answered
                        ? i === questions[current].correct ? '#10b98133' : i === selected ? '#ef444433' : 'var(--bg-tertiary)'
                        : 'var(--bg-tertiary)',
                    color: 'var(--text-primary)'
                }}>
                    {opt}
                </button>
            ))}
            {answered && (
                <p style={{ color: 'var(--accent-green)', marginTop: '1rem' }}>
                    {questions[current].explanation}
                </p>
            )}
        </div>
    );
}
```

## GitHub Pages Deploy

```yaml
# .github/workflows/deploy.yml
name: Deploy to GitHub Pages
on:
  push:
    branches: [main]

permissions:
  contents: read
  pages: write
  id-token: write

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    steps:
      - uses: actions/checkout@v4
      - uses: actions/configure-pages@v4
      - uses: actions/upload-pages-artifact@v3
        with:
          path: '.'
      - id: deployment
        uses: actions/deploy-pages@v4
```

---

## Due Approcci Architetturali

### Approccio 1: CDN-Based (CONSIGLIATO per nuove presentazioni)
**Usare quando**: Presentazione a moduli, deploy immediato, nessun build step
**Stack**: React 18 CDN + Babel standalone + HTML puro + CSS variables
**Progetti**: presentazione-vpn ⭐, presentazione-firewall-acl, presentazione-ipv6

```
presentazione-ARGOMENTO/
├── index.html          # Dashboard con card moduli
├── modulo1.html        # Slide React inline
├── modulo2.html
├── ...
├── quiz.html
└── .github/workflows/deploy.yml
```

**Vantaggi**: zero setup, ogni file è autonomo, funziona offline, si carica da file://

### Approccio 2: Build-Based (per dispense complesse)
**Usare quando**: 40+ slide, TypeScript necessario, componenti riusabili
**Stack**: React + Vite 5 + TypeScript + Tailwind CSS 4 + Lucide React
**Progetti**: presentazione-crittografia (70 slide), dispensa-sqlite (46 slide), presentazione-oop

```
dispensa-ARGOMENTO/
├── src/
│   ├── slides/         # Un file .tsx per categoria
│   ├── components/     # SlideViewer, Dashboard, Navigation
│   └── App.tsx
├── vite.config.ts
├── tailwind.config.js
└── .github/workflows/deploy.yml
```

**Vantaggi**: TypeScript, hot reload, componenti riusabili, PDF export

### Approccio 3: Gioco Educativo Multiplayer
**Usare quando**: Attività in classe collaborativa, game-based learning
**Stack**: Node.js + Express + Socket.io + HTML5
**Progetto**: escape-room (ISO/OSI con 14 enigmi, max 7 giocatori)

```
gioco-ARGOMENTO/
├── server.js           # Express + Socket.io
├── public/
│   ├── index.html      # UI giocatori
│   └── admin.html      # Controllo docente
├── levels/             # Enigmi per livello
└── modules/            # Game managers
```

**Vantaggi**: multiplayer real-time, timer condiviso, leaderboard, narrativa

---

## Responsive per LIM (Pattern VPN — Referenza)

```css
/* Responsive per LIM 2400x1600 fino a mobile */
:root {
    --font-size-base: clamp(0.85rem, 1.5vw, 1.1rem);
    --font-size-lg: clamp(1rem, 2vw, 1.4rem);
    --font-size-xl: clamp(1.2rem, 2.5vw, 1.8rem);
    --font-size-hero: clamp(1.5rem, 3vw, 2.5rem);
    --padding-slide: clamp(1rem, 3vw, 2.5rem);
    --gap-grid: clamp(0.75rem, 2vw, 1.5rem);
}

/* SVG responsive (diagrammi di rete) */
svg {
    max-width: 100%;
    height: auto;
    viewBox: "0 0 800 400";  /* sempre impostare viewBox */
}

/* Grid responsive */
.grid-auto {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(min(280px, 100%), 1fr));
    gap: var(--gap-grid);
}
```

---

## Tecniche Avanzate

### Simulatore con Stato Persistente
```javascript
// Pattern VPN: simulatore con configurazione modificabile
const [config, setConfig] = useState({ protocol: 'WireGuard', encryption: 'ChaCha20' });
const [connectionState, setConnectionState] = useState('disconnected');

// Step-by-step handshake visualization
const steps = ['Key Exchange', 'Authentication', 'Session Setup', 'Data Transfer'];
const [currentStep, setCurrentStep] = useState(0);
```

### Drag-and-Drop per Quiz (Pattern OOP)
```javascript
// Quiz drag-and-drop: abbina concetto → definizione
const [pairs, setPairs] = useState([...shuffled]);
const handleDrop = (item, target) => {
    const isCorrect = item.concept === target.definition;
    setFeedback({ [target.id]: isCorrect ? 'correct' : 'wrong' });
};
```

### Navigazione da Tastiera (Standard)
```javascript
useEffect(() => {
    const handler = (e) => {
        if (e.key === 'ArrowRight' || e.key === ' ') next();
        if (e.key === 'ArrowLeft') prev();
        if (e.key === 'Escape') window.location.href = 'index.html';
        if (e.key >= '1' && e.key <= '9') goToSlide(parseInt(e.key) - 1);
    };
    window.addEventListener('keydown', handler);
    return () => window.removeEventListener('keydown', handler);
}, [current]);
```

### Accent Color per Modulo (Standard)
```javascript
// Palette standard — usare sempre questi colori per consistenza visiva
const accentColors = {
    modulo1: '#3b82f6',   // Blu — Introduzione/Fondamenti
    modulo2: '#10b981',   // Verde — Concetti base
    modulo3: '#f59e0b',   // Arancione — Intermedio
    modulo4: '#ef4444',   // Rosso — Avanzato/Critico
    modulo5: '#8b5cf6',   // Viola — Pratico/Lab
    modulo6: '#06b6d4',   // Ciano — Quiz/Riepilogo
    special: '#00d4aa',   // Teal — usato in VPN per accent globale
};
```

---

## Gioco Educativo: Pattern Socket.io (Escape Room)

```javascript
// server.js — gestione stanze multiplayer
const rooms = new Map(); // roomCode → { players, scores, currentLevel, timer }

io.on('connection', (socket) => {
    socket.on('join-room', ({ code, playerName }) => {
        const room = rooms.get(code);
        room.players.push({ id: socket.id, name: playerName, score: 0 });
        socket.join(code);
        io.to(code).emit('room-update', room);
    });

    socket.on('submit-answer', ({ code, answer, level }) => {
        const correct = checkAnswer(level, answer);
        const points = correct ? calculatePoints(level, hintsUsed) : 0;
        updateScore(code, socket.id, points);
        io.to(code).emit('answer-result', { playerId: socket.id, correct, points });
    });
});

// Hint penalty system: -20% per hint usato
const calculatePoints = (level, hintsUsed) =>
    Math.floor(level.basePoints * Math.pow(0.8, hintsUsed));
```

---

## Presentazioni Esistenti — Catalogo Completo

| Progetto | Argomento | Approccio | Moduli | Slide | Interattivo | Materia | Ultimo update |
|---------|-----------|-----------|--------|-------|-------------|---------|---------------|
| `presentazione-vpn` ⭐ | VPN (IPsec, OpenVPN, WireGuard) | CDN | 6 | 51 | Quiz 15q + simulatori | Sistemi e Reti | Mar 2026 |
| `presentazione-firewall-acl` | Firewall & ACL Cisco/Linux | CDN | 6 | 45+ | 4 simulatori + quiz | Sistemi e Reti | Gen 2026 |
| `presentazione-ipv6` | IPv6, SLAAC, dual-stack | CDN | 6 | 48+ | Calcolatori + validatori | Sistemi e Reti | Gen 2026 |
| `presentazione-oop` | OOP C# e UML | CDN+Tailwind | 5 | 41 | 5 quiz multi-tipo | Informatica | Ott 2025 |
| `presentazione-crittografia` | RSA, AES, OpenSSL | Build (Vite+TS) | 8 | 70 | Dashboard navigabile | Sistemi e Reti | Nov 2025 |
| `dispensa-sqlite` | SQL e SQLite | Build (Vite+TS) | 7 | 46 | Dashboard navigabile | Informatica | Set 2025 |
| `google-workspace-slides` | Google Workspace, Gemini AI | Build (CRA) | 7 | 50+ | Navigazione cliccabile | Vario | Set 2025 |
| `escape-room` | ISO/OSI (gioco) | Node+Socket.io | 7 layer | 14 enigmi | Multiplayer 2-7 giocatori | Sistemi e Reti | Gen 2026 |

⭐ = progetto di riferimento (più recente, più completo)

---

## Best Practices

1. **Scegliere CDN** per nuove presentazioni a moduli (zero build, deploy immediato)
2. **Scegliere Build** (Vite+TS) per dispense con 40+ slide o componenti riusabili
3. **Scegliere Node+Socket.io** per giochi in classe con più studenti
4. **File singoli autonomi** (CDN) — ogni modulo.html si apre indipendentemente
5. **Responsive con clamp()** — funziona su LIM 2400x1600 e smartphone
6. **Dark theme sempre** — meno affaticamento visivo su proiettore
7. **Colori standard per modulo** — palette fissa per riconoscimento rapido
8. **Navigazione tastiera** — frecce, spazio, ESC (+ numeri 1-9 per salto diretto)
9. **SVG con viewBox** — diagrammi di rete sempre responsive
10. **Almeno 1 simulatore per modulo** — più efficace di slide statiche
11. **Quiz finale** con feedback immediato e spiegazione
12. **GitHub Pages deploy** — automatico su push con workflow YAML incluso
13. **`clamp()` per tipografia** — mai `px` fissi, mai `vw` puri
14. **CLAUDE.md nel progetto** — documenta design system e pattern (come in presentazione-vpn)
