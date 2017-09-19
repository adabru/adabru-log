require! [dgram,fs,stream]


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
  d = date_logrotate!
  switch
    # no log file yet
    case not files[f]?
      files[f] = date: d, stream: fs.createWriteStream "./log/#{d}-#{f}", flags: 'a'
    # log file for obsolete month
    case d isnt files[f].date
      files[f].date = d
      files[f].stream.end!
      files[f].stream = fs.createWriteStream "./log/#{d}-#{f}", flags: 'a'
    # log size exceeded
    case files[f].logsize > logsizelimit
      return
    # log file ready
    else
  files[f].stream.write s


# message processing

sender_name = {}
recv_msg = (msg, id) ->
  # each sender must send its (unique) name as first message
  if not sender_name[id]?
    sender_name[id] = msg
  else
    s = msg.toString('utf-8').split('\n').map((line) -> "#{date_timestamp!} #line").join('\n') + '\n'
    write_log s, sender_name[id]


# udp server

server = dgram.createSocket 'udp4'
server.on 'error', (err) ->
  console.log "server error:\n#{err.stack}"
  server.close!
server.on 'message', (msg, rinfo) ->
  recv_msg msg, "#{rinfo.address}:#{rinfo.port}"
server.on 'listening', ->
  addr = server.address!
  console.log "log server listening on #{addr.address}:#{addr.port}"


# extern interface

exports <<< start: (port)->server.bind port
