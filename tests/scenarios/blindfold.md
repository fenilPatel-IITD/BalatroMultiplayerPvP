# Basic Blindfold accessibility

## Scope

Blindfold remains optional. The adapter uses its menu collector, widget actions,
proxies, and navigation graph. The multiplayer main menu is a vertical list in
reading order, including MPAPI's separate account/back panel. Modal menus retain
Blindfold's normal navigation. Mode buttons have contextual names, and the PvP
blind's Ready/Unready action is included in its spoken details.

This does not add narration for opponent scores, timers, player joins, ready-state
notifications, or every custom gameplay panel. It does not modify either mod's
keybindings or bypass MPAPI's disabled-control checks.

## Automated checks

From the repository root:

```sh
lua tests/unit/blindfold_test.lua
```

The standalone checks cover optional/loading behavior, main-menu and lobby focus
metadata, changing labels, mode selectors, disabled controls, account-panel roots,
page identity, widget action forwarding, and the PvP blind proxy.

To additionally exercise Blindfold's actual collector, proxies, dispatcher, and
navigation graph, pass a local checkout or unpacked release (containing `src/`):

```sh
lua tests/unit/blindfold_test.lua /path/to/Blindfold
```

These integration checks have been run against Blindfold v1.0.9 and its development
`main`. They use synthetic game UI nodes, not a running game or speech backend.
`texlua` can also run this test when a standalone Lua interpreter is unavailable.

## In-game checklist (manual; not covered by the synthetic-node tests)

Use a supported Blindfold install and a screen reader, plus two Balatro clients
for the lobby checks. Use Blindfold's configured navigation/confirm controls; no
mouse should be needed for the following flows.

1. From the title screen, reach the multiplayer account panel and select PvP.
   Confirm that the account panel and Back controls are reachable even though
   they are not children of the main-menu UIBox.
2. In PvP, visit Find Game, Create Lobby, Practice, Join by Code, Join from
   Clipboard, and Leaderboard. Confirm each enabled control has a readable label.
   Use Back to return. Unavailable controls must not activate.
3. In Find Game, switch Ranked/Casual and navigate the mode actions. Confirm the
   spoken label includes the mode (not just "QUEUE"). Start a search and confirm
   its action reads "CANCEL"; cancel and confirm it returns to "QUEUE". Verify a
   standing-refused queue still opens its explanation rather than starting a search.
4. Create a private lobby, join from the second client, and navigate both clients'
   lobby controls. On the guest, toggle Ready/Unready and re-read the button.
   Confirm Start Game is unavailable to the host until the guest is ready.
5. Open Lobby Options as host and change a ruleset with the cycle's left/right
   controls. Exercise toggles and, where applicable, role/team selection. Confirm
   the guest cannot activate host-only controls. Test the lobby-code text field
   and Join confirmation using Blindfold's existing text-entry behavior.
6. Start the match and reach a PvP blind. Confirm its select control includes the
   current Ready/Unready action, can toggle it, and still reads the blind details.
   Open and close the pause menu; normal gameplay navigation must remain intact.
7. Repeat the menu/lobby flows with Blindfold removed. Existing mouse/controller
   input and disabled-button behavior must remain unchanged.
