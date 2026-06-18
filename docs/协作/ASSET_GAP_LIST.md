# Asset Gap List

Track missing, placeholder, or not-yet-integrated assets here.

| Path | Status | Problem | Owner |
|---|---|---|---|
| `assets/sprites/units/base/unit_infantry/` | waiting_validation | Runtime loading still inconsistent because unit ID naming is mixed | programming |
| `scenes/ui/diplomacy/diplomacy_panel.gd` background asset usage | waiting_integration | Extra runtime background block should be removed | programming |

## Status meaning
- `missing`: required source file is absent
- `placeholder`: usable temporary asset exists
- `waiting_integration`: asset or rule exists but code/scene integration is not complete
- `waiting_validation`: integrated but not yet verified in editor/runtime
- `done`: verified usable