extends RefCounted
class_name UpgradeDefinitions

const STANDARD_UPGRADE_COSTS: Array[Dictionary] = [
	{"iron": 5,  "gold": 0, "crystal": 0},
	{"iron": 10, "gold": 0, "crystal": 0},
	{"iron": 20, "gold": 0, "crystal": 0},
	{"iron": 35, "gold": 0, "crystal": 0},
	{"iron": 60, "gold": 0, "crystal": 0},
	{"iron": 5,  "gold": 0, "crystal": 0},
	{"iron": 10, "gold": 0, "crystal": 0},
	{"iron": 20, "gold": 0, "crystal": 0},
	{"iron": 35, "gold": 0, "crystal": 0},
	{"iron": 60, "gold": 0, "crystal": 0},
]

## Mining skill upgrade costs.
## Levels 1-6 (indices 0-5): custom iron/gold progression.
const MINING_UPGRADE_COSTS: Array[Dictionary] = [
	{"iron": 5,    "gold": 0,   "crystal": 0},
	{"iron": 10,   "gold": 0,   "crystal": 0},
	{"iron": 20,   "gold": 1,   "crystal": 0},
	{"iron": 50,   "gold": 10,  "crystal": 0},
	{"iron": 100,  "gold": 25,  "crystal": 0},
	{"iron": 1000, "gold": 100, "crystal": 0},
]

## Mining damage per upgrade level (index = level, 0 = no upgrade).
const MINING_DAMAGE_VALUES: Array[int] = [1, 1, 2, 3, 6, 9, 12]
const MINING_SPEED_INTERVAL_VALUES: Array[float] = [2.2, 2.0, 1.9, 1.8, 1.7, 1.6, 1.4]
const CRIT_CHANCE_VALUES: Array[float] = [0.0, 0.03, 0.06, 0.09, 0.12, 0.15, 0.18]
const CRIT_DAMAGE_MULTIPLIER: float = 2.0

const ORBIT_MODE_UPGRADE_COSTS: Array[Dictionary] = [
	{"iron": 5, "gold": 0, "crystal": 0},
	{"iron": 5, "gold": 0, "crystal": 0},
	{"iron": 5, "gold": 0, "crystal": 0},
	{"iron": 5, "gold": 0, "crystal": 0},
	{"iron": 5, "gold": 0, "crystal": 0},
]

const MAX_MINING_UPGRADE_LEVEL: int = 6
const MAX_MINING_SPEED_UPGRADE_LEVEL: int = 6
const MAX_ENERGY_FIELD_UPGRADE_LEVEL: int = 1
const MAX_ENERGY_ORB_MAGNET_UPGRADE_LEVEL: int = 5
const MAX_DAMAGE_AURA_UPGRADE_LEVEL: int = 3
const MAX_ORBIT_MODE_UPGRADE_LEVEL: int = 5
const MAX_CRIT_CHANCE_UPGRADE_LEVEL: int = 6
const MAX_LASER_DURATION_UPGRADE_LEVEL: int = 6
const MAX_DUAL_LASER_UPGRADE_LEVEL: int = 1

const ATTRACTION_SKILL_IRON_COST: int = 3
const DROP_COLLECTION_SKILL_GOLD_COST: int = 3

const DEVELOPER_MODE_COST: int = 0
const DEVELOPER_MODE_IRON_REWARD: int = 100000
const DEVELOPER_MODE_GOLD_REWARD: int = 100000
const DEVELOPER_MODE_CRYSTAL_REWARD: int = 100000

# ── Silah kilit maliyetleri ────────────────────────────────────────────────────
const LASER_UNLOCK_COST:  Dictionary = {"iron": 15, "gold": 2,  "crystal": 0}
const BULLET_UNLOCK_COST: Dictionary = {"iron": 20, "gold": 5,  "crystal": 0}
const ROCKET_UNLOCK_COST: Dictionary = {"iron": 0,  "gold": 15, "crystal": 1}

# ── Silah upgrade maliyetleri (level başına, 0–2) ──────────────────────────────
const WEAPON_UPGRADE_COSTS: Array[Dictionary] = [
	{"iron": 10, "gold": 2,  "crystal": 0},
	{"iron": 20, "gold": 5,  "crystal": 0},
	{"iron": 40, "gold": 10, "crystal": 0},
]
const MAX_WEAPON_UPGRADE_LEVEL: int = 3

# ── Lazer değerleri (level 0–3) ────────────────────────────────────────────────
const LASER_COOLDOWN_VALUES: Array[float] = [0.18, 0.14, 0.11, 0.08]
const LASER_DAMAGE_VALUES:   Array[float] = [3.0,  4.0,  5.5,  7.0]

# ── Seken mermi değerleri (level 0–3) ─────────────────────────────────────────
const BULLET_DAMAGE_VALUES:   Array[float] = [4.0,  5.0,  7.0,  10.0]
const BULLET_BOUNCE_VALUES:   Array[int]   = [3,    4,    5,    6   ]
const BULLET_COOLDOWN_VALUES: Array[float] = [1.20, 1.00, 0.85, 0.70]

# ── Roket değerleri (level 0–3) ────────────────────────────────────────────────
const ROCKET_DAMAGE_VALUES:   Array[float] = [12.0, 16.0, 22.0, 30.0]
const ROCKET_RADIUS_VALUES:   Array[float] = [80.0, 100.0,125.0,155.0]
const ROCKET_COOLDOWN_VALUES: Array[float] = [3.0,  2.5,  2.0,  1.6 ]
