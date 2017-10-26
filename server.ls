require! [net,fs,stream,http,util]


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

tcp_server = net.createServer (c) ->
  c.setEncoding 'utf8'
  id = "#{c.remoteAddress}:#{c.remotePort}"
  c.on 'data', (msg) ->
    recv_msg msg, id
  c.on 'end', ->
    close_con id
    console.log "#id disconnected"
tcp_server.on 'error', (err) ->
  throw err
tcp_server.on 'listening', ->
  addr = tcp_server.address!
  console.log "log tcp-server listening on #{addr.address}:#{addr.port}"


# http server

http_server = http.createServer (req, res) ->
  answer = (code, message) -> res.writeHead code ; res.end message
  switch
    case req.url is "/"
      # get all names and sizes of log files
      (e,files) <- fs.readdir './log', _
      Promise.all(
        files.map (f) -> new Promise (y,n) -> fs.stat "./log/#f", (e,s) ->
          if e? then n e else y {name: /[^-]*$/.exec(f).0, s.size, mtime:s.mtimeMs}
      ).catch(
        (e) -> console.log e ; answer 500, e.stack
      ).then (files) ->
        logs = {}
        for f in files
          logs[f.name] ?= {f.name, size:0, mtime:0}
          logs[f.name].size += f.size
          logs[f.name].mtime >?= f.mtime
        answer 200, JSON.stringify Object.values(logs).map (l) -> l <<< active: l.name in Object.values sender_name
    else
      # concat logs of one process
      name = /[^\/]+$/.exec(req.url).0
      (e,files) <- fs.readdir './log', _
      files = files.filter (f) -> f.endsWith "-#{name}"
      if files.length is 0
        return answer 404, "no logs for process #name yet"
      Promise.all(
        files.map (f) -> (util.promisify fs.readFile) "./log/#f", "utf-8"
      ).catch(
        (e) -> console.log e ; answer 500, e.stack
      ).then (ds) ->
        answer 200, "[#{ds.join '\n'}{}]"
http_server.on "listening", ->
  addr = http_server.address!
  console.log "log http-server listening on #{addr.address}:#{addr.port}"


# graceful SIGTERM

process.on 'SIGTERM', ->
  close_all_logs!
  process.nextTick process.exit


# extern interface

exports <<< start: (tcpport, httpport) -> tcp_server.listen tcpport ; http_server.listen httpport, "::1"
