require! [net,fs,stream]


# configuration

logsizelimit = 10e6


# log formatting

pad = (i, n) -> "#{"0".repeat n}#i".substr -n
date_timestamp = ->
  # 2017-07-12 13:45:54
  d = new Date!
  [d.getUTCFullYear!, pad(d.getUTCMonth!+1, 2), pad(d.getUTCDate!, 2)].join('-') + ' ' + [pad(d.getUTCHours!, 2), pad(d.getUTCMinutes!, 2), pad(d.getUTCSeconds!, 2)].join(':')


# log storage

date_logrotate = ->
  # 2017-07
  d = new Date!
  d.getUTCFullYear! + '-' + pad d.getUTCMonth!+1, 2
try fs.mkdirSync './log' catch e then if e.code isnt 'EEXIST' then console.log e ; process.exit -1
files = {}
write_log = (s, f) ->
  console.log "writing log"
  d = date_logrotate!
  switch
    # no log file yet
    case not files[f]?
      files[f] = logsize: 0, date: d, stream: fs.createWriteStream "./log/#{d}-#{f}", flags: 'a'
    # log file for obsolete month
    case d isnt files[f].date
      files[f].stream.end!
      files[f] = logsize: 0, date: d, stream: fs.createWriteStream "./log/#{d}-#{f}", flags: 'a'
    # log size exceeded
    case files[f].logsize > logsizelimit
      return
    # log file ready
    else
  files[f].stream.write s
close_log = (f) ->
  console.log "closing log"
  files[f]?.stream?.end!
  delete files[f]
close_all_logs = ->
  Object.values(files).forEach (f) -> f.stream?.end!

# message processing

sender_name = {}
recv_msg = (msg, id) ->
  console.log "received [#{msg}]"
  # each sender must send its (unique) name as first message
  if not sender_name[id]?
    [, sender_name[id], msg] = /(.*?)\n(.*)$/.exec(msg) ? []
  if msg isnt ''
    s = JSON.stringify(d:Date.now!, s:msg) + ",\n"
    write_log s, sender_name[id]
close_con = (id) ->
  close_log sender_name[id]
  delete sender_name[id]


# tcp server

server = net.createServer (c) ->
  c.setEncoding 'utf8'
  id = "#{c.remoteAddress}:#{c.remotePort}"
  c.on 'data', (msg) ->
    recv_msg msg, id
  c.on 'end', ->
    close_con id
    console.log "#id disconnected"
server.on 'error', (err) ->
  throw err
server.on 'listening', ->
  addr = server.address!
  console.log "log server listening on #{addr.address}:#{addr.port}"


# graceful SIGTERM

process.on 'SIGTERM', ->
  close_all_logs!
  process.nextTick process.exit

# extern interface

exports <<< start: (port)->server.listen port
