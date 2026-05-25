# Conventions de conception — NavigationToy

Ce document résume les règles à suivre lors de la création de scènes, de scripts et d’assets pour garder le projet cohérent.

---

## 0. Principes généraux

### Godot d’abord

- **Privilégier toujours** les fonctionnalités natives Godot (`NavigationRegion3D`, `NavigationAgent3D`, `NavigationServer3D`, groupes, signaux, scènes instanciées, etc.) avant d’écrire des systèmes maison (graphes BFS, pathfinding custom, etc.).
- En cas de doute : consulter la **documentation officielle Godot** (version du projet, ex. 4.6) et les **tutos / bonnes pratiques** récents sur le web avant de proposer une implémentation.

### Monde de développement (`DevWorldLayout`)

Chemin dans l’arbre : **`Main/NavigationRegion3D/Ground/DevWorldLayout`** (raccourci courant : *DevWorld layout*).

- Quand c’est demandé pour faciliter le dev : ajouter des **scènes entières** (`instance=ExtResource(...)`) sous `DevWorldLayout`, **rangées proprement** (nom explicite, `transform` sur la grille, pas d’éclatement des nœuds internes dans `main.tscn`).
- Sous-conteneurs typiques : `PlacedPaths` (chemins), bâtiments instanciés au même niveau, `PathsNavRegion` (navmesh chemins).

### Rôle de `DevWorldLayout` (`scripts/dev_world_layout.gd`)

Le script ne doit contenir **que** des responsabilités liées à :

1. **Ajout / suppression** d’instances de scènes dans l’arbre sous `DevWorldLayout` (layout de dev).
2. **Sync navigation** après changement du layout : rebake `PathsNavRegion`, délégation du rebake sol à `Main.sync_navigation()` (pas de logique gameplay PNJ, UI, modes construction, etc.).

Toute autre logique (déplacement, errance, outils de pose dynamique) vit ailleurs (`main.gd`, modes `*BuildMode`, scripts de scène).

---

## 1. Organisation du projet

| Élément | Convention |
|---------|------------|
| Scènes réutilisables | Dossier `scenes/` (`Cube.tscn`, `WoodenHouse.tscn`, …) |
| Scripts | Dossier `scripts/` |
| Ressources partagées | Dossier `ressources_dev/` |
| Nommage des scènes | **Anglais**, PascalCase (`WoodenHouse`, `TentSite`, `DefaultPNJ`, `Ball`) |
| Nommage des scripts | snake_case (`cube_build_mode.gd`, `placement_utils.gd`) |

---

## 2. Repère, sol et grille

- **Sol du jeu** : plan à **y = 0** (voir `NavigationRegion3D/Ground` dans `main.tscn`).
- **Plateau** : environ 30×30 m, centré autour de **(-0.5, 0, -0.5)**.
- **Grille de placement** : pas de **1 m** sur X et Z (`PlacementUtils.snap_position_to_ground_grid`).
- **Tiles du sol** : le plateau est découpé en **tuiles de 1×1 m** sur les axes X et Z. Chaque tile est une case dont le centre repère est en coordonnées **entières** `(x, z)`.
- **Pivot des scènes** : nœud racine `Node3D` à **(0, 0, 0)** dans la scène locale.

### Bâtiments sur la grille

- Les **bâtiments** (maisons, tentes, sites, etc.) sont **toujours placés sur cette grille** : position du pivot en **x** et **z** entiers dans `main.tscn` ou via les modes construction.
- L’**emprise au sol** d’un bâtiment s’exprime en **nombre de tiles** (ex. 3×4 tiles = 3 m × 4 m), alignée sur les bords des cases (voir règles ci-dessous).
- Les chemins (`DirtPath`) et le placement dynamique (cubes, rampes) utilisent la **même grille** : une tile = une case 1×1 m.

### Alignement sur la grille

- Côtés **pairs** (2 m, 4 m) : centrer sur le pivot avec débordement égal (ex. ±1 m, ±2 m).
- Côtés **impairs** (3 m) : aligner en **unités entières** depuis le pivot, pas en demi-unités.
  - Exemple maison 3 m de large : **1 m** vers -X, **2 m** vers +X (x ∈ [-1, 2]), pas ±1,5 m.
- **Hauteur** : poser la base des meshes sur **y = 0** en décalant le mesh de **+half_height** sur Y (comme le cube : offset `y = 0.5` pour une hauteur de 1 m).

---

## 3. Physique et collisions

| Règle | Détail |
|-------|--------|
| Couche de collision | **`collision_layer = 1`** pour le décor statique (sol, cubes, bâtiments) |
| Forme par défaut | `BoxShape3D` sauf forme explicite (ex. rampe → `ConvexPolygonShape3D`) |
| Raycasts / navmesh | Les instances décoratives vont sous `NavigationRegion3D/Ground` |

---

## 4. Types de scènes

### 4.1 Bâtiments et structures (`WoodenHouse` — modèle recommandé)

Structure cible pour les nouvelles constructions :

```
NomDeLaScene (Node3D)          ← pivot (0, 0, 0)
├── Visuals (Node3D)           ← tous les éléments visuels
│   ├── … (MeshInstance3D)
│   └── … (détails décoratifs : porte, fenêtre, …)
└── HouseBody (StaticBody3D)   ← une seule collision englobante
	└── CollisionShape3D
```

**Règles :**

- Emprise et placement calés sur la **grille de tiles 1×1** (voir §2).
- Tous les **MeshInstance3D** sous `Visuals`.
- **Une seule** `CollisionShape3D` (box englobante du volume principal).
- Détails **purement visuels** (porte, enseigne…) : mesh sous `Visuals`, **sans collision**.
- Matériaux : `StandardMaterial3D` en sub-resource dans la scène.

**Exemple** : `WoodenHouse.tscn` — emprise 3×4 m, hauteur 2 m, collision 3×2×4 centrée à `(0.5, 1, 0)`.

### 4.2 Emplacements / sites (`TentSite`)

Pour les zones composées (tente + sol local, etc.) :

```
TentSite (Node3D)
├── TentBody (StaticBody3D)    ← mesh + collision de l’objet principal
└── PadBody (StaticBody3D)     ← dalle de sol locale (optionnel)
```

- Pivot **centré** sur l’emprise totale (ex. 2×2 m → x, z ∈ [-1, 1]).
- Chaque partie avec mesh **et** collision si elle doit bloquer / être détectée au raycast.
- **Évolution possible** : migrer vers le modèle `Visuals` + collision unique quand la scène grossit.

### 4.3 Props simples (`Cube`, `Ramp`)

Structure minimale pour les objets de construction :

```
CubeBody (StaticBody3D)        ← racine = corps physique
├── CollisionShape3D
└── MeshInstance3D
```

- Racine = `StaticBody3D` (pas de nœud pivot intermédiaire).
- Mesh et collision **même transform** (souvent `y = half_height`).
- Scale sur le **parent** `StaticBody3D` si besoin d’agrandir mesh + collision ensemble.

### 4.4 PNJ humains (`DefaultPNJ`)

- Scène : `scenes/DefaultPNJ.tscn`, script `scripts/default_pnj.gd` (`class_name DefaultPNJ`).
- Groupe : `selectable_pnj` (et `selectable_character` pour la sélection existante).
- Déplacement : **uniquement** `NavigationAgent3D` (`target_position` → `get_next_path_position()`), pas de BFS ni de route grille.
- Errance : destinations tirées sur **layer chemin** (`LAYER_PATH`) via `NavigationUtils.pick_random_point_on_map` ; repli `AGENT_LAYERS` si échec.
- Préférence des chemins : navmesh monolithique `PathsNavRegion` (rebake depuis meshes `path_nav_geometry`) + sol sans herbe sous les tiles (`NavGroundCutout` par `DirtPath`).
- Vitesse sur chemin : `NavigationUtils.is_near_path_tile` (proximité d’une tile `PlacedPaths`) → `path_move_speed` > `off_path_move_speed`.
- `NavigationAgent3D.navigation_layers` = herbe + chemins (`NavigationLayers.AGENT_LAYERS`).

---

## 5. Intégration dans `main.tscn`

- Layout de développement : tout passe par **`NavigationRegion3D/Ground/DevWorldLayout`** (`scripts/dev_world_layout.gd`, `@tool`) — voir §0 pour le périmètre du script.
- Dans `main.tscn`, n’enregistrer que des **instances** de scènes (`instance=ExtResource(...)`) + `transform` — pas les nœuds internes (`Visuals`, `HouseBody`, etc.). Le script `DevWorldLayout` ne doit pas appeler `owner` sur les enfants d’une scène instanciée.
- Sur demande : placer des **scènes complètes** sous `DevWorldLayout` (maisons, tentes, sites…) avec des noms clairs (`WoodenHouse_West`, `TentSite_Main`, …) et des positions sur la grille.
- Chemins dev : conteneur `DevWorldLayout/PlacedPaths` ; les `DirtPath` sont créés par `DevWorldLayout` ou le mode **Chemin**.
- Décor statique du plateau (hors layout dev) : instances sous **`NavigationRegion3D/Ground`** (cubes, rampes placés en jeu).
- Après ajout ou déplacement manuel d’obstacles : **rebaker la navmesh** dans l’éditeur (`NavigationRegion3D` → Bake).
- Les modes construction appellent `Main.sync_navigation()` (rebake chemins + sol + `map_force_update`).

### 5.1 Navigation : pré vs chemins

Constantes : `scripts/navigation_layers.gd`. Helpers : `scripts/navigation_utils.gd`. Rebake chemins : `scripts/paths_nav_region.gd` (`PathsNavRegion` sous `DevWorldLayout`).

| Région | Layer | `travel_cost` | `enter_cost` | Rôle |
|--------|-------|---------------|--------------|------|
| `NavigationRegion3D` (main) | 1 (pré) | 30 | 10 | Herbe (trous sous chemins via `NavGroundCutout`) |
| `PathsNavRegion` | 2 (chemin) | 0,1 | 0 | Navmesh continue depuis meshes `path_nav_geometry` |
| `DirtPath/PathNavigation` | 2 | — | — | **Désactivé** si `PathsNavRegion` présent (legacy) |

Meshes visuels des `DirtPath` : groupe `path_nav_geometry`. Rebake : `Main.sync_navigation()` après pose chemin, sync layout, cube/rampe.

`scripts/path_network.gd` : grille / visuels uniquement.

Spawn PNJ : `LAYER_PATH`, repli `AGENT_LAYERS`.

**Debug** : lignes rouges sur obstacle (ex. tente) = ancien `NavigationAgent3D.debug_enabled` le long du bord de navmesh ; désactivé par défaut sur `DefaultPNJ`.

**Réglage** : coûts dans `navigation_layers.gd`, `default_edge_connection_margin` ≥ 0,6 dans `project.godot`.

---

## 6. Scripts

| Sujet | Convention |
|-------|------------|
| Contrôleur principal | `main.gd` sur le nœud `Main` |
| Utilitaires partagés | `class_name` + méthodes `static` (ex. `PlacementUtils`) |
| Types de scène sans `class_name` | `const X = preload("res://scripts/x.gd")` si besoin de typage |
| Modes outil 3D | `extends Node3D` (accès à `get_world_3d()` pour les raycasts) |
| Signaux | Pour coupler des systèmes faiblement liés (ex. `movement_started` sur la balle) |

---

## 7. UI

- Interface 2D : nœuds sous **`CanvasLayer`** dans `main.tscn`.
- Éléments qui suivent un objet 3D : contrôle dans le `CanvasLayer`, position recalculée via `Camera3D.unproject_position` (ex. étoile au-dessus d’un chat).
- **Boussole** : [`scenes/CompassIndicator.tscn`](scenes/CompassIndicator.tscn) + [`scripts/compass_indicator.gd`](scripts/compass_indicator.gd), en haut à droite. Le **nord** du monde est la direction **+X / +Z** sur le plan horizontal (`Vector3(1, 0, 1).normalized()`). La flèche suit la caméra via `unproject_position` (pas de mesh `North` en runtime).

---

## 8. Checklist avant de valider une nouvelle scène

- [ ] Fichier dans `scenes/`, nom PascalCase en anglais
- [ ] Pivot à `(0, 0, 0)` ; emprise cohérente avec la grille **1×1**
- [ ] Bâtiment : position **x** et **z** entiers si instance dans `main.tscn`
- [ ] Base des volumes sur **y = 0**
- [ ] Côtés impairs alignés en unités entières (1+2, pas 1,5+1,5)
- [ ] Bâtiment : `Visuals` + une collision box englobante
- [ ] Décor sans gameplay : pas de collision inutile
- [ ] `collision_layer = 1` si objet statique du plateau
- [ ] Instance placée sous `NavigationRegion3D/Ground` si pertinent
- [ ] Navmesh rebakée si la scène est dans `main.tscn`

---

## 9. Évolutions et dette connue

| Scène | État | Note |
|-------|------|------|
| `WoodenHouse.tscn` | À jour | Modèle de référence bâtiments |
| `TentSite.tscn` | Ancien style | Deux `StaticBody3D` séparés ; OK pour les sites simples |
| `Cube2.tscn` | Non versionné | Scène de dev, ne pas prendre comme référence |

Lors d’une modification d’une scène existante, **appliquer les conventions actuelles** si le changement le justifie ; inutile de tout migrer d’un coup.

---

## 10. Utilisation avec Cursor / IA

Lors d’une demande de création de scène ou d’asset, mentionner :

> « Suis `docs/CONVENTIONS.md` »

ou préciser la famille : *bâtiment*, *emplacement*, *prop de construction*.

### Règles pour l’assistant (Cursor / IA)

| Règle | Comportement attendu |
|-------|----------------------|
| **Godot natif** | Toujours privilégier l’API et les nœuds Godot ; pas de réinvention si le moteur couvre le besoin (voir §0). |
| **Documentation** | Consulter la doc Godot et, si besoin, des tutos / discussions récents sur le web avant de figer une approche technique. |
| **DevWorldLayout** | Respecter le périmètre §0 : instances sous `DevWorldLayout` + sync nav uniquement. |
| **Scènes entières** | Sur demande explicite : instancier des scènes complètes sous `DevWorldLayout`, bien nommées et positionnées — ne pas exploser les PackedScenes dans `main.tscn`. |
| **Gros changements** | Si une demande impliquerait **plus de ~100 lignes** de code nouveau ou modifié : **proposer un plan** et **ne pas coder** tant que l’utilisateur ne l’a pas demandé explicitement (ex. « implémente le plan », « vas-y »). |

Exceptions au seuil des 100 lignes : corrections mineures (bugfix, typo, renommage, 1–2 lignes), ou demande explicite de coder malgré tout.
