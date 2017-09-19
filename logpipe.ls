require! [dgram]

pipe = (name, port) ->
  sock = dgram.createSocket('udp4');
  process.stdin.setEncoding 'utf8'
  process.stdin.on 'readable', ->
    chunk = process.stdin.read!
    if not chunk? then return
    s = Date.now! + " " + chunk.toString('utf-8')
    sock.send s, port

  process.stdin.on 'end', ->
  f.end "#{date_timestamp!} exit\n"

exports <<< pipe
