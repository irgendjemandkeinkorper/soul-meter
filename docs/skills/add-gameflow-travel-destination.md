# Skill: add a GameFlow travel destination

Use this workflow when adding a new gameplay location reachable from an existing
scene. Travel is registry-driven: scene nodes may request travel, but they do
not call `change_scene_to_file()` or `SceneLoader` directly.

## Recipe

1. Create the destination scene and its `LocationDefinition` resource under
   `world/locations/`. Set a stable `id`, `scene_path`, spawn map, and
   `allowed_gameplay = true`.
2. Preload the definition in `globals/location_registry.gd` and add it to
   `LocationRegistry.ALL`. This makes the destination resolvable and includes
   it in `GameFlow.GAMEPLAY_SCENES`.
3. Add a `TravelExit` instance to the source scene (or use the existing
   `BuildingDoor` transition for an interior). Configure `target_scene`,
   `target_location_id`, `spawn_id`, label, and any required flags.
4. Add the reciprocal exit when the player should be able to return. Keep both
   directions in the location/transition registries.
5. Add or update spawn markers in the destination scene and verify the stable
   spawn id resolves to the intended marker.
6. Test the registry, both exit directions, lock conditions, and the destination
   spawn. The travel path is `TravelExit → GameFlow.travel() → LoadDestination →
   GameFlow`'s `travel` event → `SceneLoader`.

## Guardrails

- UI and world actors send the request through `GameFlow.travel()`; they do not
  own scene loading policy.
- A destination must be present in `LocationRegistry` before a `TravelExit`
  references it.
- Use stable location and spawn ids in saves and transitions; do not make a
  scene path the only identity.
- Run the relevant integration tests and `scripts/acceptance_gate.sh` when the
  location changes generated data or save behavior.

## Existing examples

- `world/starting_town.tscn` → `world/test_room.tscn` via `RoadToTheWilds`.
- `actors/building_door/transitions/trial_hall_enter.tres` → the Trial Hall
  interior, with the reciprocal `trial_hall_exit` transition.
