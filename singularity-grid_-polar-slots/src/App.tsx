/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import React, { useState, useEffect, useMemo, useCallback } from 'react';
import { motion, AnimatePresence } from 'motion/react';
import { 
  Zap, 
  Flame, 
  Droplets, 
  Wind, 
  Sun, 
  Moon, 
  Star, 
  CircleDot,
  RefreshCw,
  Play
} from 'lucide-react';

// --- Constants ---
const LAYERS = 5;
const R_START = 100;
const DR = 50;
const TARGET_ARC_LENGTH = 50;
const SYMBOLS = [
  { icon: Zap, color: '#facc15', label: 'zap' },
  { icon: Flame, color: '#f87171', label: 'flame' },
  { icon: Droplets, color: '#60a5fa', label: 'water' },
  { icon: Wind, color: '#34d399', label: 'wind' },
  { icon: Sun, color: '#fbbf24', label: 'sun' },
  { icon: Moon, color: '#a78bfa', label: 'moon' },
  { icon: Star, color: '#f472b6', label: 'star' },
];

// --- Types ---
interface CellData {
  id: string;
  layer: number; // 0 to LAYERS-1
  index: number;
  symbol: typeof SYMBOLS[0];
  isPattern: boolean;
  isAbsorbed: boolean;
}

// --- Utils ---
const getSegmentsForLayer = (layerIdx: number) => {
  const rMid = R_START + layerIdx * DR + DR / 2;
  const circumference = 2 * Math.PI * rMid;
  return Math.round(circumference / TARGET_ARC_LENGTH);
};

const polarToCartesian = (r: number, angleDegrees: number) => {
  const angleRadians = (angleDegrees - 90) * (Math.PI / 180);
  return {
    x: r * Math.cos(angleRadians),
    y: r * Math.sin(angleRadians),
  };
};

const describeArc = (rInner: number, rOuter: number, startAngle: number, endAngle: number) => {
  const arcInnerStart = polarToCartesian(rInner, startAngle);
  const arcInnerEnd = polarToCartesian(rInner, endAngle);
  const arcOuterStart = polarToCartesian(rOuter, startAngle);
  const arcOuterEnd = polarToCartesian(rOuter, endAngle);

  const largeArcFlag = endAngle - startAngle <= 180 ? '0' : '1';

  return [
    `M ${arcOuterStart.x} ${arcOuterStart.y}`,
    `A ${rOuter} ${rOuter} 0 ${largeArcFlag} 1 ${arcOuterEnd.x} ${arcOuterEnd.y}`,
    `L ${arcInnerEnd.x} ${arcInnerEnd.y}`,
    `A ${rInner} ${rInner} 0 ${largeArcFlag} 0 ${arcInnerStart.x} ${arcInnerStart.y}`,
    'Z',
  ].join(' ');
};

// --- Components ---

interface AnnularSectorProps {
  key?: React.Key;
  cell: CellData;
  rInner: number;
  rOuter: number;
  startAngle: number;
  endAngle: number;
  onAbsorb: () => void;
}

const AnnularSector = ({ 
  cell, 
  rInner, 
  rOuter, 
  startAngle, 
  endAngle,
  onAbsorb
}: AnnularSectorProps) => {
  const Icon = cell.symbol.icon;
  const midAngle = (startAngle + endAngle) / 2;
  const midR = (rInner + rOuter) / 2;
  const iconPos = polarToCartesian(midR, midAngle);

  return (
    <motion.g
      initial={{ opacity: 0, scale: 0.8 }}
      animate={{ 
        opacity: cell.isAbsorbed ? 0 : 1, 
        scale: cell.isAbsorbed ? 0.2 : 1,
        x: cell.isAbsorbed ? 0 : 0,
        y: cell.isAbsorbed ? 0 : 0,
      }}
      transition={{ duration: 0.5 }}
      onAnimationComplete={() => {
        if (cell.isAbsorbed) onAbsorb();
      }}
    >
      <path
        d={describeArc(rInner, rOuter, startAngle, endAngle)}
        fill="transparent"
        stroke={cell.isPattern ? cell.symbol.color : 'rgba(255,255,255,0.05)'}
        strokeWidth={cell.isPattern ? 2 : 1}
        className="transition-colors duration-300"
      />
      {cell.isPattern && (
        <path
          d={describeArc(rInner, rOuter, startAngle, endAngle)}
          fill={cell.symbol.color}
          fillOpacity={0.15}
        />
      )}
      
      <g transform={`translate(${iconPos.x}, ${iconPos.y})`}>
        <motion.g
          animate={cell.isPattern ? { scale: [1, 1.2, 1], rotate: [0, 5, -5, 0] } : {}}
          transition={{ repeat: Infinity, duration: 2 }}
        >
          <Icon 
            size={16} 
            color={cell.symbol.color} 
            style={{ 
              filter: cell.isPattern ? `drop-shadow(0 0 8px ${cell.symbol.color})` : 'none',
              opacity: cell.isPattern ? 1 : 0.6
            }}
            transform="translate(-8, -8)"
          />
        </motion.g>
      </g>
    </motion.g>
  );
};

export default function App() {
  const [grid, setGrid] = useState<CellData[][]>([]);
  const [isSpinning, setIsSpinning] = useState(false);
  const [score, setScore] = useState(0);

  // Initialize Grid
  const generateInitialGrid = useCallback(() => {
    const newGrid: CellData[][] = [];
    for (let l = 0; l < LAYERS; l++) {
      const segmentCount = getSegmentsForLayer(l);
      const layerCells: CellData[] = [];
      for (let i = 0; i < segmentCount; i++) {
        layerCells.push({
          id: `cell-${l}-${i}-${Math.random()}`,
          layer: l,
          index: i,
          symbol: SYMBOLS[Math.floor(Math.random() * SYMBOLS.length)],
          isPattern: false,
          isAbsorbed: false,
        });
      }
      newGrid.push(layerCells);
    }
    return newGrid;
  }, []);

  useEffect(() => {
    setGrid(generateInitialGrid());
  }, [generateInitialGrid]);

  // Pattern Analysis
  const checkPatterns = (currentGrid: CellData[][]) => {
    const nextGrid = [...currentGrid.map(layer => [...layer])];
    let found = false;

    // A simple pattern check: adjacent cells in the same layer or same angle across layers
    // For this demo, let's look for same-symbol neighbors in the same layer
    nextGrid.forEach((layer, l) => {
      layer.forEach((cell, i) => {
        const prev = layer[(i - 1 + layer.length) % layer.length];
        const next = layer[(i + 1) % layer.length];
        
        if (cell.symbol.label === prev.symbol.label && cell.symbol.label === next.symbol.label) {
          cell.isPattern = true;
          prev.isPattern = true;
          next.isPattern = true;
          found = true;
        }
      });
    });

    return { nextGrid, found };
  };

  const spin = () => {
    if (isSpinning) return;
    setIsSpinning(true);

    // Randomize all symbols
    const newGrid = grid.map(layer => 
      layer.map(cell => ({
        ...cell,
        id: `cell-${cell.layer}-${cell.index}-${Math.random()}`,
        symbol: SYMBOLS[Math.floor(Math.random() * SYMBOLS.length)],
        isPattern: false,
        isAbsorbed: false,
      }))
    );

    setGrid(newGrid);

    // After animation delay, check patterns
    setTimeout(() => {
      const { nextGrid, found } = checkPatterns(newGrid);
      setGrid(nextGrid);
      setIsSpinning(false);
      
      if (found) {
        setScore(s => s + 100);
        // Trigger absorption after showing pattern
        setTimeout(() => {
          setGrid(prev => prev.map(layer => 
            layer.map(cell => cell.isPattern ? { ...cell, isAbsorbed: true } : cell)
          ));
        }, 1000);
      }
    }, 1000);
  };

  const refillGrid = () => {
    setGrid(prev => prev.map(layer => 
      layer.map(cell => {
        if (cell.isAbsorbed) {
          return {
            ...cell,
            id: `cell-${cell.layer}-${cell.index}-${Math.random()}`,
            symbol: SYMBOLS[Math.floor(Math.random() * SYMBOLS.length)],
            isPattern: false,
            isAbsorbed: false,
          };
        }
        return cell;
      })
    ));
  };

  return (
    <div className="fixed inset-0 bg-[#050505] text-white overflow-hidden font-sans selection:bg-yellow-500/30">
      {/* Background Decor */}
      <div className="absolute inset-0 pointer-events-none overflow-hidden">
        <div 
          className="absolute inset-0 opacity-20"
          style={{
            background: `radial-gradient(circle at 50% 50%, #1e1b4b 0%, transparent 70%),
                        radial-gradient(circle at 20% 80%, #312e81 0%, transparent 40%),
                        radial-gradient(circle at 80% 20%, #4c1d95 0%, transparent 40%)`
          }}
        />
        <div className="absolute inset-0 atmosphere" />
      </div>

      <div className="relative z-10 w-full h-full flex flex-col items-center justify-center p-4">
        {/* HUD Top */}
        <div className="absolute top-8 left-8 flex flex-col gap-1">
          <span className="text-[10px] font-mono tracking-[0.2em] uppercase opacity-40">System Active</span>
          <div className="flex items-baseline gap-2">
            <h1 className="text-3xl font-light tracking-tight">SINGULARITY</h1>
            <span className="text-xs uppercase font-bold text-yellow-500/80">Beta v1.0</span>
          </div>
        </div>

        <div className="absolute top-8 right-8 text-right">
          <span className="text-[10px] font-mono tracking-[0.2em] uppercase opacity-40">Total Extraction</span>
          <div className="text-4xl font-mono font-medium text-white/90">
            {score.toLocaleString().padStart(8, '0')}
          </div>
        </div>

        {/* Game Stage */}
        <div className="relative w-full max-w-[800px] aspect-square flex items-center justify-center">
          <svg 
            viewBox="-400 -400 800 800" 
            className="w-full h-full drop-shadow-2xl"
            style={{ filter: 'drop-shadow(0 0 40px rgba(0,0,0,0.5))' }}
          >
            {/* Background Grid Lines (Polar) */}
            {[0, 1, 2, 3, 4, 5].map(l => (
              <circle 
                key={l}
                cx="0" cy="0" r={R_START + l * DR}
                fill="none"
                stroke="rgba(255,255,255,0.03)"
                strokeWidth={1}
              />
            ))}

            {/* Cells */}
            {grid.map((layer, lIdx) => {
              const rInner = R_START + lIdx * DR;
              const rOuter = rInner + DR;
              const segmentCount = layer.length;
              const angleStep = 360 / segmentCount;

              return layer.map((cell, cIdx) => (
                <AnnularSector
                  key={cell.id}
                  cell={cell}
                  rInner={rInner}
                  rOuter={rOuter}
                  startAngle={cIdx * angleStep}
                  endAngle={(cIdx + 1) * angleStep}
                  onAbsorb={refillGrid}
                />
              ));
            })}

            {/* The Sink Node (Black Hole) */}
            <g className="sink-node">
              {/* Inner Abyss */}
              <motion.circle
                r={R_START}
                fill="#000"
                stroke="rgba(255,255,255,0.1)"
                strokeWidth={2}
                animate={{ 
                  scale: [1, 1.05, 1],
                  strokeOpacity: [0.1, 0.3, 0.1]
                }}
                transition={{ repeat: Infinity, duration: 4, ease: "easeInOut" }}
              />
              {/* Event Horizon Glow */}
              <circle
                r={R_START}
                fill="url(#eventHorizon)"
                pointerEvents="none"
              />
              <defs>
                <radialGradient id="eventHorizon">
                  <stop offset="70%" stopColor="#000" stopOpacity="0" />
                  <stop offset="95%" stopColor="#fff" stopOpacity="0.1" />
                  <stop offset="100%" stopColor="#8b5cf6" stopOpacity="0.4" />
                </radialGradient>
              </defs>
              
              {/* Center Icon */}
              <motion.g
                animate={{ rotate: 360 }}
                transition={{ repeat: Infinity, duration: 20, ease: "linear" }}
              >
                <CircleDot size={40} color="white" className="opacity-10" transform="translate(-20, -20)" />
              </motion.g>
            </g>
          </svg>

          {/* Winning Overlay (Floating Numbers) */}
          <AnimatePresence>
            {isSpinning && (
              <motion.div
                initial={{ opacity: 0, scale: 0.5 }}
                animate={{ opacity: 1, scale: 1 }}
                exit={{ opacity: 0 }}
                className="absolute inset-0 flex items-center justify-center pointer-events-none"
              >
                <div className="text-[10vw] font-mono font-bold text-white/5 tracking-tighter italic">
                  SYNCING...
                </div>
              </motion.div>
            )}
          </AnimatePresence>
        </div>

        {/* Controls */}
        <div className="absolute bottom-12 flex flex-col items-center gap-6">
          <div className="flex gap-4">
            <button
               onClick={spin}
               disabled={isSpinning}
               className={`
                group relative px-12 py-4 bg-white text-black font-bold uppercase tracking-widest text-sm
                transition-all duration-300 hover:tracking-[0.5em] disabled:opacity-50 disabled:cursor-not-allowed
               `}
            >
              <div className="absolute inset-0 bg-yellow-400 transform scale-x-0 group-hover:scale-x-100 transition-transform origin-left" />
              <span className="relative z-10 flex items-center gap-2">
                {isSpinning ? <RefreshCw size={16} className="animate-spin" /> : <Play size={16} fill="currentColor" />}
                Initiate Sequence
              </span>
            </button>
          </div>

          <div className="flex gap-8 items-center text-[10px] font-mono tracking-widest text-white/40 uppercase">
             <div className="flex items-center gap-2">
                <div className="w-1.5 h-1.5 rounded-full bg-green-500 animate-pulse" />
                Signal: Stable
             </div>
             <div>Buffer: 100%</div>
             <div>Grid: Polar_5xN</div>
          </div>
        </div>
      </div>

      <style>{`
        .atmosphere {
          mask-image: radial-gradient(circle at 50% 50%, black, transparent 70%);
        }
      `}</style>
    </div>
  );
}
