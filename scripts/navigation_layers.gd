extends Object
class_name NavigationLayers

## Layer 1 : pré et obstacles rebakés (NavigationRegion3D principale).
const LAYER_GROUND := 1
## Layer 2 : tiles DirtPath (NavigationRegion3D par tile).
const LAYER_PATH := 2
## Masque agent : herbe + chemins.
const AGENT_LAYERS := LAYER_GROUND | LAYER_PATH

const GROUND_TRAVEL_COST := 30.0
const GROUND_ENTER_COST := 10.0
const PATH_TRAVEL_COST := 0.1
const PATH_ENTER_COST := 0.0

const PATH_TILE_PROXIMITY := 0.55
