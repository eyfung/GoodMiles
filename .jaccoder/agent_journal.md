## Issues
- [turn 1] `.sv.jac` extension caused Python `ModuleNotFoundError: No module named 'goodmiles.sv'` — fixed by renaming to plain `goodmiles.jac` (server is default context, no `.sv.` needed)
- [turn 1] `n != None` on dict items compiled to `_jac.dict.eq(n, null)` which calls `Object.keys(null)` → "Cannot convert undefined or null to object" — fixed by removing the None guards from for-loops (API never returns None items)
- [turn 1] `len(route) > 0` on a dict compiled to `route.length > 0` (array method) → always false — fixed by using `"neighbor" in route`
- [turn 1] `res.get("error")` compiled to `res["error"] ?? undefined`; `undefined !== null` is true so exec_error was always set — fixed by using `"error" in res` check

## Learnings
- `.sv.jac` files in subdirectories cause Python import errors (`goodmiles.sv` treated as submodule). Use plain `.jac` for server modules in subdirs.
- `n != None` where n is typed as dict compiles to `_jac.dict.eq(n, null)` which crashes on null. Avoid None checks on dict-typed loop vars.
- `len(dict)` compiles to `dict.length` (JS array method), not `Object.keys(dict).length`. Use `"key" in dict` to check dict non-emptiness.
- `dict.get("key")` compiles to `dict["key"] ?? undefined`; `undefined !== null` is true. Use `"key" in dict` for existence checks.

## Last Action
Built full GoodMiles app: services/goodmiles.jac (backend), components/NeighborsView.cl.jac, ServiceStopsView.cl.jac, OptimizeView.cl.jac, main.jac (router + sidebar). All 3 screens render. Execute trip flow works (confirmed Jordan 80→100 pts). Minor: empty error banner after execute (fixed with "error" in res check). Cleaned up template files.
