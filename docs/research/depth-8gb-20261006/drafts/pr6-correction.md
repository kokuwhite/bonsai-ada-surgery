Correction to my comment above. The long-context "regression" is my test error. The launcher is correct.

Cause: `start-server.ps1` does not read `BONSAI_BIN`. It always runs `bin\`. My test passed `BONSAI_BIN=...\bin-rc3`, but every launcher run used `bin\`, which on this rig holds `bundle-20260927`. That engine does not have the Turing one-column path (#325, +13.7 %). 43.8 / 38.2 = 1.147.

The "fast" runs started `bin-rc3\llama-server.exe` directly, so they used the right engine.

Void: the "how the server starts" table and the deep-end table in my comment above. I will post the deep-end table again when it is measured with `bundle-20261007`.

No change is necessary in the launcher for this.
