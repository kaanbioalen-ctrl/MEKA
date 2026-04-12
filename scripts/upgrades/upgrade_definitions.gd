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

const ATTRACTION_SKILL_IRON_COST: int = 3
const DROP_COLLECTION_SKILL_GOLD_COST: int = 3

const DEVELOPER_MODE_COST: int = 0
const DEVELOPER_MODE_IRON_REWARD: int = 100000
const DEVELOPER_MODE_GOLD_REWARD: int = 100000
const DEVELOPER_MODE_CRYSTAL_REWARD: int = 100000
