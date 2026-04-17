import React, { useState, useEffect, useCallback, useRef } from 'react';
import { motion, AnimatePresence } from 'motion/react';
import { 
  Zap, 
  Orbit, 
  Ghost, 
  Atom, 
  Activity, 
  Target,
  RefreshCw,
  Play,
  Pause,
  AlertTriangle
} from 'lucide-react';

// --- Constants ---
const CORE_RADIUS = 25;
const LAYER_HEIGHT = 50;
const LAYER_COUNTS = [4, 8, 16]; // Layer 0 (Inner), 1, 2 (Outer)
const SYMBOLS = [
  { id: 'A', icon: Zap, color: '#facc15' }, // Yellow
  { id: 'B', icon: Orbit, color: '#60a5fa' }, // Blue
  { id: 'C', icon: Ghost, color: '#a78bfa' }, // Purple
  { id: 'D', icon: Atom, color: '#4ade80' }, // Green
];
const TOTAL_DROPS_TARGET = 40;
const TICK_RATE = 1000; // ms for logic

// --- Types ---
type DropState = 'spawning' | 'grid' | 'collapsing' | 'consumed';

type Drop = {
  id: string;
  typeIndex: number;
  state: DropState;
  layer: number;
  cell: number;
  // Polar for spawning/asteroids
  r: number;
  theta: number; 
  // Visual position (for smooth transitions)
  x: number;
  y: number;
};

type GridCell = {
  dropId: string | null;
};

type GameState = {
  drops: Record<string, Drop>;
  grid: GridCell[][];
  score: number;
};

// --- Utils ---
const getRandomSymbol = () => Math.floor(Math.random() * SYMBOLS.length);

export default function App() {
  const [gameState, setGameState] = useState<GameState>({
    drops: {},
    grid: [
      Array(4).fill(null).map(() => ({ dropId: null })),
      Array(8).fill(null).map(() => ({ dropId: null })),
      Array(16).fill(null).map(() => ({ dropId: null })),
    ],
    score: 0
  });
  const [isPlaying, setIsPlaying] = useState(false);
  const [ticker, setTicker] = useState(0);

  // Initialize: All drops start outside
  useEffect(() => {
    const initialDrops: Record<string, Drop> = {};
    for (let i = 0; i < TOTAL_DROPS_TARGET; i++) {
      const id = `drop-${i}`;
      const angle = Math.random() * 360;
      const dist = 400 + Math.random() * 200; // Start way outside
      initialDrops[id] = {
        id,
        typeIndex: getRandomSymbol(),
        state: 'spawning',
        layer: -1,
        cell: -1,
        r: dist,
        theta: angle,
        x: Math.cos(angle * Math.PI / 180) * dist,
        y: Math.sin(angle * Math.PI / 180) * dist
      };
    }
    setGameState(prev => ({ ...prev, drops: initialDrops }));
  }, []);

  const processTick = useCallback(() => {
    setGameState(prev => {
      const nextGrid = prev.grid.map(layer => layer.map(cell => ({ ...cell })));
      const nextDrops: Record<string, Drop> = { ...prev.drops };
      let newScore = prev.score;

      // 1. CLEAR CONSUMED: If any drop reached (0,0), reset it to outside
      Object.keys(nextDrops).forEach(id => {
          const d = nextDrops[id] as Drop;
          if (d.state === 'consumed') {
              const angle = Math.random() * 360;
              const dist = 500;
              nextDrops[id] = {
                  ...d,
                  state: 'spawning',
                  typeIndex: getRandomSymbol(),
                  r: dist,
                  theta: angle,
                  x: Math.cos(angle * Math.PI / 180) * dist,
                  y: Math.sin(angle * Math.PI / 180) * dist
              } as Drop;
          }
          // If in collapsing state, they move towards (0,0) - visually handled by getPolarCoords
          // But logistically, we mark them consumed after a tick
          if (d.state === 'collapsing') {
              nextDrops[id] = { ...d, state: 'consumed' } as Drop;
          }
      });

      // 2. PATTERN DETECTION (Horizontal only - same layer)
      const toCollapseIds = new Set<string>();
      for (let l = 0; l < 3; l++) {
        const count = LAYER_COUNTS[l];
        for (let c = 0; c < count; c++) {
          const d1 = nextGrid[l][c].dropId;
          const d2 = nextGrid[l][(c + 1) % count].dropId;
          const d3 = nextGrid[l][(c + 2) % count].dropId;

          if (d1 && d2 && d3) {
            const drop1 = nextDrops[d1] as Drop;
            const drop2 = nextDrops[d2] as Drop;
            const drop3 = nextDrops[d3] as Drop;
            if (drop1.state === 'grid' && drop2.state === 'grid' && drop3.state === 'grid') {
                if (drop1.typeIndex === drop2.typeIndex && 
                    drop1.typeIndex === drop3.typeIndex) {
                  toCollapseIds.add(d1);
                  toCollapseIds.add(d2);
                  toCollapseIds.add(d3);
                }
            }
          }
        }
      }

      if (toCollapseIds.size > 0) {
        newScore += toCollapseIds.size * 10;
        toCollapseIds.forEach(id => {
            const d = nextDrops[id] as Drop;
            nextGrid[d.layer][d.cell].dropId = null;
            nextDrops[id] = { ...d, state: 'collapsing' } as Drop;
        });
      }

      // 3. GRAVITY CASCADE: Upper to lower (Clockwise prioritized or just radial)
      // The user wants: "üst katmandakiler saat yönü kuralına göre altkatmanlara düşsün"
      // We process from inner (L0) to outer (L2)
      for (let l = 0; l < 2; l++) {
          for (let c = 0; c < LAYER_COUNTS[l]; c++) {
              if (nextGrid[l][c].dropId === null) {
                  // Find source in row above
                  // For L0 (4) <- L1 (8): L0[c] takes from L1[2c] or L1[2c+1]
                  const p1 = c * 2;
                  const p2 = (c * 2 + 1) % LAYER_COUNTS[l+1];
                  
                  let sourceId = nextGrid[l+1][p1].dropId || nextGrid[l+1][p2].dropId;
                  if (sourceId) {
                      const sourceCell = nextGrid[l+1][p1].dropId ? p1 : p2;
                      nextGrid[l+1][sourceCell].dropId = null;
                      nextGrid[l][c].dropId = sourceId;
                      const sDrop = nextDrops[sourceId] as Drop;
                      nextDrops[sourceId] = { ...sDrop, layer: l, cell: c } as Drop;
                  }
              }
          }
      }

      // 4. FILL FROM EXTERNAL: Boundary (L2) takes from 'spawning' drops
      const spawningDrops = (Object.values(nextDrops) as Drop[])
        .filter(d => d.state === 'spawning')
        .sort((a, b) => a.r - b.r); // Pull the closest ones

      for (let c = 0; c < LAYER_COUNTS[2]; c++) {
          if (nextGrid[2][c].dropId === null && spawningDrops.length > 0) {
              const drop = spawningDrops.shift()!;
              nextGrid[2][c].dropId = drop.id;
              nextDrops[drop.id] = { 
                  ...drop, 
                  state: 'grid', 
                  layer: 2, 
                  cell: c 
              };
          }
      }

      return { drops: nextDrops, grid: nextGrid, score: newScore };
    });
  }, []);

  // Frame Loop for "Physical" continuous movement
  useEffect(() => {
    let frameId: number;
    const update = () => {
        setGameState(prev => {
            const nextDrops: Record<string, Drop> = { ...prev.drops };
            let changed = false;

            Object.keys(nextDrops).forEach(id => {
                const d = nextDrops[id] as Drop;
                if (d.state === 'spawning') {
                    // Force components: Pull (R decreases) + Orbit (Theta increases)
                    const pullSpeed = 1.0;
                    const orbitSpeed = 1.0; // Clockwise
                    
                    const newR = Math.max(200, d.r - pullSpeed); // Stop at boundary
                    const newTheta = (d.theta + orbitSpeed) % 360;
                    
                    nextDrops[id] = { 
                        ...d, 
                        r: newR, 
                        theta: newTheta,
                        x: Math.cos(newTheta * Math.PI / 180) * newR,
                        y: Math.sin(newTheta * Math.PI / 180) * newR
                    } as Drop;
                    changed = true;
                } else if (d.state === 'grid') {
                    // Update visual x,y based on cell
                    const targetR = CORE_RADIUS + (d.layer + 0.5) * LAYER_HEIGHT;
                    const count = LAYER_COUNTS[d.layer];
                    const angle = (d.cell / count) * 360 + (360 / count / 2);
                    const targetX = Math.cos(angle * Math.PI / 180) * targetR;
                    const targetY = Math.sin(angle * Math.PI / 180) * targetR;
                    
                    // Simple easing
                    nextDrops[id] = {
                        ...d,
                        x: d.x + (targetX - d.x) * 0.2,
                        y: d.y + (targetY - d.y) * 0.2
                    } as Drop;
                    changed = true;
                } else if (d.state === 'collapsing') {
                    // Fast pull to center
                    nextDrops[id] = {
                        ...d,
                        x: d.x * 0.7,
                        y: d.y * 0.7,
                        r: d.r * 0.7
                    } as Drop;
                    changed = true;
                }
            });

            if (!changed) return prev;
            return { ...prev, drops: nextDrops };
        });
        frameId = requestAnimationFrame(update);
    };

    if (isPlaying) {
        frameId = requestAnimationFrame(update);
    }
    return () => cancelAnimationFrame(frameId);
  }, [isPlaying]);

  // Tick for high-level logic (matches, cascade)
  useEffect(() => {
    if (!isPlaying) return;
    const interval = setInterval(() => {
      setTicker(t => t + 1);
      processTick();
    }, TICK_RATE);
    return () => clearInterval(interval);
  }, [isPlaying, processTick]);

  return (
    <div className="min-h-screen bg-[#0c0d10] text-[#e0e0e0] font-sans overflow-hidden flex flex-col items-center justify-center relative">
      <div className="absolute inset-0 opacity-5 pointer-events-none" 
           style={{ backgroundImage: 'radial-gradient(circle at center, #6b7280 1px, transparent 1px)', backgroundSize: '40px 40px' }} />

      <div className="absolute inset-0 pointer-events-none grid grid-cols-[280px_1fr_280px] p-[30px] z-10">
        <div className="panel p-5 flex flex-col gap-[15px] pointer-events-auto h-fit">
          <div className="panel-header pb-2 mb-[10px]">Core Dynamics</div>
          <div className="flex justify-between items-baseline text-[13px]">
            <span className="stat-label">Gravity Force</span>
            <span className="stat-value text-[#00ff9d]">CONSTANT</span>
          </div>
          <div className="flex justify-between items-baseline text-[13px]">
            <span className="stat-label">Score</span>
            <span className="stat-value text-white">{gameState.score}</span>
          </div>
          <div className="flex justify-between items-baseline text-[13px]">
            <span className="stat-label">Grid Status</span>
            <span className="stat-value">{(Object.values(gameState.drops) as Drop[]).filter(d => d.state === 'grid').length}/28</span>
          </div>
          <div className="flex justify-between items-baseline text-[13px]">
            <span className="stat-label">System Flow</span>
            <span className="stat-value text-[#00ff9d]">ACTIVE</span>
          </div>

          <div className="panel-header mt-5 pb-2 mb-[10px]">Cascade Log</div>
          <div className="font-mono text-[10px] text-[#6b7280] leading-[1.6]">
            [SYS] Initializing Spawning Loop<br />
            [SYS] Clockwise Force Enabled<br />
            [SYS] Polar Grid Syncing...<br />
            [SYS] Core Absorption: {gameState.score / 10} Units
          </div>
        </div>

        <div className="flex flex-col items-center justify-between py-10">
          <div className="text-center">
            <h1 className="font-mono text-[18px] tracking-[4px] mb-[5px] uppercase">Radial Collapse Engine</h1>
            <p className="text-[10px] text-[#6b7280] uppercase">Physics Matrix v1.0.5</p>
          </div>
        </div>

        <div className="panel p-5 flex flex-col gap-[15px] pointer-events-auto h-fit">
          <div className="panel-header pb-2 mb-[10px]">Matrix Status</div>
          <div className="flex justify-between items-baseline text-[13px]">
            <span className="stat-label">Matches</span>
            <span className="stat-value text-[#00ff9d]">{String(gameState.score/30).padStart(2, '0')} SEQ</span>
          </div>
          
          <div className="border border-dashed border-[#2a2d35] p-[10px] mt-[10px]">
            <div className="stat-label mb-[5px]">Core Sync</div>
            <div className="flex gap-[5px] items-center">
              <div className={`w-[20px] h-[20px] rounded-full transition-colors ${isPlaying ? 'bg-[#00ff9d]' : 'bg-[#6b7280]'}`}></div>
              <div className={`w-[20px] h-[20px] rounded-full transition-colors ${isPlaying ? 'bg-[#00ff9d]' : 'bg-[#6b7280]'}`}></div>
              <div className={`w-[20px] h-[20px] rounded-full transition-colors ${isPlaying ? 'bg-[#00ff9d]' : 'bg-[#6b7280]'}`}></div>
            </div>
            <div className="stat-label mt-[5px]">ROTATION_LOCKED</div>
          </div>

          <div className="panel-header mt-5 pb-2 mb-[10px]">Orbital Data</div>
          <div className="flex justify-between items-baseline text-[13px]">
            <span className="stat-label">Inbound Drops</span>
            <span className="stat-value">
              {(Object.values(gameState.drops) as Drop[]).filter(d => d.state === 'spawning').length}
            </span>
          </div>
          <div className="h-[100px] border-l-2 border-[#2a2d35] mt-[10px] relative">
            <div className="absolute bottom-[10%] left-[10px] text-[10px] text-[#00ff9d]">ORBITAL_FORCE_CONSTANT</div>
          </div>
        </div>
      </div>

      <div className="relative w-full h-[700px] flex items-center justify-center">
        <svg viewBox="-300 -300 600 600" className="w-full h-full max-w-[700px] max-h-[700px] select-none">
          <circle cx="0" cy="0" r={CORE_RADIUS + 1 * LAYER_HEIGHT} className="grid-line opacity-20" strokeDasharray="2 4" />
          <circle cx="0" cy="0" r={CORE_RADIUS + 2 * LAYER_HEIGHT} className="grid-line opacity-20" strokeDasharray="2 4" />
          <circle cx="0" cy="0" r={CORE_RADIUS + 3 * LAYER_HEIGHT} className="grid-line opacity-20" strokeDasharray="2 4" />

          {[0, 1, 2].map(l => (
            <React.Fragment key={l}>
                {Array(LAYER_COUNTS[l]).fill(0).map((_, c) => {
                    const count = LAYER_COUNTS[l];
                    const startAngle = (c / count) * 360;
                    const endAngle = ((c + 1) / count) * 360;
                    const rIn = CORE_RADIUS + l * LAYER_HEIGHT;
                    const rOut = CORE_RADIUS + (l + 1) * LAYER_HEIGHT;
                    
                    const x1 = Math.cos((startAngle * Math.PI) / 180) * rIn;
                    const y1 = Math.sin((startAngle * Math.PI) / 180) * rIn;
                    const x2 = Math.cos((startAngle * Math.PI) / 180) * rOut;
                    const y2 = Math.sin((startAngle * Math.PI) / 180) * rOut;
                    const x3 = Math.cos((endAngle * Math.PI) / 180) * rOut;
                    const y3 = Math.sin((endAngle * Math.PI) / 180) * rOut;
                    const x4 = Math.cos((endAngle * Math.PI) / 180) * rIn;
                    const y4 = Math.sin((endAngle * Math.PI) / 180) * rIn;

                    return (
                        <path 
                            key={`seg-${l}-${c}`}
                            d={`M ${x1} ${y1} L ${x2} ${y2} A ${rOut} ${rOut} 0 0 1 ${x3} ${y3} L ${x4} ${y4} A ${rIn} ${rIn} 0 0 0 ${x1} ${y1} Z`}
                            className="cell fill-[#2a2d35]/10 stroke-[#2a2d35]/30"
                        />
                    );
                })}
            </React.Fragment>
          ))}

          {/* Drops */}
          {(Object.values(gameState.drops) as Drop[]).map(drop => {
              const color = SYMBOLS[drop.typeIndex].color;
              const radius = drop.state === 'spawning' ? 8 : 12;

              return (
                <circle
                  key={drop.id}
                  cx={drop.x}
                  cy={drop.y}
                  r={radius}
                  fill={color}
                  className="transition-transform duration-75"
                  style={{
                    filter: `drop-shadow(0 0 8px ${color}44)`,
                    opacity: drop.state === 'consumed' ? 0 : 1
                  }}
                />
              );
            })}

          <circle cx="0" cy="0" r={CORE_RADIUS} className="sink-node" />
        </svg>
      </div>

      <div className="mt-8 flex gap-4 z-20">
        <button 
          onClick={() => setIsPlaying(!isPlaying)}
          className="flex items-center gap-2 bg-[#00ff9d]/10 hover:bg-[#00ff9d]/20 px-6 py-3 rounded-none border border-[#00ff9d]/30 transition-all active:scale-95 text-[#00ff9d] pointer-events-auto"
        >
          {isPlaying ? <Pause size={18} /> : <Play size={18} />}
          <span className="text-[11px] font-mono font-bold tracking-[2px] uppercase">
            {isPlaying ? 'SUSPEND_MATRIX' : 'INIT_FORCE'}
          </span>
        </button>
        <button 
          onClick={() => window.location.reload()}
          className="p-3 rounded-none bg-white/5 border border-white/10 hover:bg-white/10 transition-all text-white pointer-events-auto"
        >
          <RefreshCw size={18} />
        </button>
      </div>
    </div>
  );
}

