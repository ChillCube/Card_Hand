# Card Hand API Reference
Generated: 2026-05-20

a godot addon that lets you create a deck of cards. Used for Card2D node

## Class: CardHand
**Inherits:** [NodeArranger](git@github.com:ChillCube/2d_node_arranger/blob/main/DOCUMENTATION.md)


### ⚙️ Inspector Variables (Exported)
| Property | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| **grid** | `Grid;` | `-` | Optional Grid reference used by cards in this hand for snap-to-grid placement |
| **mouse_reactive** | `bool` | `true` | If true, cards respond to mouse proximity with lift and spread effects |
| **reaction_radius** | `float` | `300.0` | Distance in pixels from the hand center within which mouse proximity effects are active |
| **mouse_lift_height** | `float` | `-50.0` | Y offset applied to the hovered card (negative = upward lift) |
| **horizontal_spread** | `float` | `20.0` | Horizontal distance in pixels that neighboring cards push away from the hovered card |
| **base_z_index** | `int` | `0` | Z-index assigned to the leftmost card; each subsequent card increments by 1 |
| **max_z_bonus** | `int` | `10` | Extra Z-index added to the hovered card so it renders on top |

### 🔔 Signals
| Signal | Arguments | Description |
| :--- | :--- | :--- |
| **card_added** | `card: Node2D` |  Emitted when a card node is added to the hand |
| **card_removed** | `card: Node2D` |  Emitted when a card node is removed from the hand |
| **card_hovered** | `card: Node2D` |  Emitted when the mouse begins hovering over a specific card |
| **card_hover_ended** | - |  Emitted when the mouse stops hovering over any card in the hand |

### 🛠️ Methods
| Method | Arguments | Returns | Description |
| :--- | :--- | :--- | :--- |
| **get_index_at_position()** | `global_pos: Vector2` | `int` |  Returns the child index (clamped) closest to the given global position based on horizontal spacing |

---

