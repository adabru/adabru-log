require! [net]

pipe = (name, port) ->
  sock = writable: false

  process.stdin.setEncoding 'utf8'
  process.stdin.on 'readable', ->
    if not sock.writable then return
    chunk = process.stdin.read!
    if not chunk? then return
    sock.write chunk
  process.stdin.on 'end', ->
    sock.end!
    process.exit 0

  connect = ->
    sock := net.createConnection port
    sock.on 'error', (e) ->
    sock.on 'close', ->
      console.log 'log connection closed, reconnecting'
      return setTimeout connect, 5000
    sock.on 'connect', ->
      sock.write "#name\n"
      if (chunk = process.stdin.read!)?
        sock.write chunk
  connect!

exports <<< {pipe}
