require! [net]

pipe = (name, port) ->
  sock = writable: false
  exit = false

  process.stdin.setEncoding 'utf8'
  process.stdin.on 'readable', ->
    if not sock.writable then return
    chunk = process.stdin.read!
    console.log "writing [#{chunk}]"
    if not chunk? then return
    sock.write chunk
  process.stdin.on 'end', ->
    sock.end!
    exit := true
    # timeout for socket to finish
    setTimeout process.exit, 10000

  connect = ->
    sock := net.createConnection port
    sock.writable = false
    sock.on 'error', (e) ->
      sock.end!
      sock.writable = false
    sock.on 'close', ->
      # exit immediately
      if exit
        process.exit!
      if not exit
        console.log 'socket closed, reconnecting...'
        return setTimeout connect, 5000
    sock.on 'connect', ->
      sock.writable = true
      sock.write "#name\n"
      if (chunk = process.stdin.read!)?
        sock.write chunk
  connect!

exports <<< {pipe}
