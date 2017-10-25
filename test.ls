#!/usr/bin/env lsc

require! [child_process]

cpS = child_process.spawn "sh", [
# exec necessary for killing
# see https://nodejs.org/dist/latest-v8.x/docs/api/child_process.html#child_process_subprocess_kill_signal
"-c", "echo hi && exec ./cli.js start 1566"
], {stdio: 'pipe'}
cpS.stdout.on 'data', (d) -> console.log "\x1b[1mserver\x1b[22m #{d.trim!}"
cpS.stderr.on 'data', (d) -> console.log "\x1b[91mserver\x1b[39m #{d.trim!}"
cpS.on 'close', (code) ->
  console.log "\x1b[1mserver closed\x1b[22m"
  if code isnt 0 then process.exitCode := -1

cpC = child_process.spawn "sh", [
"-c", "echo yolo | ./cli.js pipe gg 1566"
], {stdio: 'pipe'}
cpC.stdout.on 'data', (d) -> console.log "\x1b[1mclient\x1b[22m #{d.trim!}"
cpC.stderr.on 'data', (d) -> console.log "\x1b[91mclient\x1b[39m #{d.trim!}"
cpC.on 'close', (code) ->
  console.log "\x1b[1mclient closed\x1b[22m"
  cpS.kill "SIGTERM"
  if code isnt 0 then process.exitCode := -1
# cpS.kill "SIGTERM"

[cpS.stdout, cpS.stderr, cpC.stdout, cpC.stderr].map (s) -> s.setEncoding 'utf8'
