# Fire-time entry point for OS-native scheduled sends

Reads serialized args, invokes
[`mc_send()`](https://newgraphenvironment.github.io/mc/reference/mc_send.md),
logs heartbeats, and cleans up the plist + args JSON whether the send
succeeded or failed.

## Usage

``` r
run_scheduled_send(args_json_path)
```

## Arguments

- args_json_path:

  Path to the JSON file written by the backend at schedule time (e.g.
  `~/.mc/scheduled/<uuid>.json`).

## Value

Invisibly `NULL`. Side effects: log entries,
[`mc_send()`](https://newgraphenvironment.github.io/mc/reference/mc_send.md)
call, cleanup of scheduling artifacts.
