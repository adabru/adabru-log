#!/usr/bin/env lsc

# return (require './absh').absh {o: 5}

require! [fs,util,vm]
require! [livescript]

log = console.log
print = (o) -> console.log util.inspect o,{+colors}
write = (s) -> process.stdout.write s
flatten = (arr) -> [].concat.apply [], arr
absh = (o) ->
  buf =
    content: ''
    pos: 0
  history =
    filename: "#{process.env.HOME}/.livescript_repl.history"
    entries: []
    pos: -1
  try history.entries = fs.readFileSync(history.filename, 'utf8').split '\n' catch e then
  global <<< o
  process.stdin
    ..setEncoding 'utf8'
    ..setRawMode true
    ..resume!
    ..on 'data', callback=(d) ->
      posToGeo = (cursor, buffer=buf.content) ->
        let i=cursor+2, s="> "+buffer, C=process.stdout.columns, j=0
          while i >= 0
            n = s.indexOf '\n'
            if n isnt -1 and n < C
              if i <= n then return x:i, y:j
              i -= n + 1 ; s = s.slice n + 1
            else
              if i < C then return x:i, y:j
              i -= C ; s = s.slice C
            j++
      changePos = (newPos, oldPos=buf.pos, hold=true) ->
        let p0 = posToGeo(oldPos), p1 = posToGeo(newPos)
          if (dx = p1.x - p0.x) > 0 then write '\u001b[C'.repeat dx else write '\u001b[D'.repeat -dx
          if (dy = p1.y - p0.y) > 0 then write '\u001b[B'.repeat dy else write '\u001b[A'.repeat -dy
        if hold then buf.pos = newPos
      fixCursor = (pos) ->
        if posToGeo(pos).x is 0
          write '•\u001b[D'
      repaint = -> changePos 0,buf.pos,false ; write "\u001b[J#{buf.content}" ; fixCursor buf.content.length ; changePos buf.pos, buf.content.length, false
      exit = ->
        write '\n'
        process.stdin
          ..pause!
          ..setRawMode false
          ..removeListener 'data', callback
        try fs.writeFileSync history.filename, history.entries.join '\n'
      switch d
        # Page Up
        case '\u001b[5~' then
        # Page Down
        case '\u001b[6~' then
        # Cursor Up
        case '\u001b[A'
          pos = history.entries.slice!.reverse!.findIndex (x,i) -> i > history.pos and x.startsWith buf.content.slice 0,buf.pos
          if pos isnt -1
            history.pos = pos
            buf.content = history.entries[*-pos-1]
            repaint!
        # Cursor Down
        case '\u001b[B'
          let H = history.entries.length
            pos = history.entries.findIndex (x,i) -> i > (H - 1 - history.pos) and x.startsWith buf.content.slice 0,buf.pos
            if pos isnt -1
              history.pos = pos = H-1 - pos
              buf.content = history.entries[*-pos-1]
              repaint!
        # Cursor Forward
        case '\u001b[C' then changePos buf.pos+1 <? buf.content.length
        # Cursor Back
        case '\u001b[D' then changePos buf.pos-1 >? 0
        # Control + Left
        case '\u001b[1;5D'
          r = /[^\w]*[\w]*/gy
            ..lastIndex = buf.content.length - buf.pos
          if r.test Array.from(buf.content).reverse!.join ''
            changePos (buf.content.length - r.lastIndex) >? 0
          else
            changePos 0
        # Control + Right
        case '\u001b[1;5C'
          r = /[^\w]*[\w]*/gy
            ..lastIndex = buf.pos
          if r.test buf.content
            changePos r.lastIndex <? buf.content.length
          else
            changePos buf.content.length - 1
        # Home
        case '\u001b[1~' then changePos 0
        # End
        case '\u001b[4~' then changePos buf.content.length
        # Backspace
        case '\u007f'
          if buf.pos > 0
            buf.content = "#{buf.content.slice 0,buf.pos-1}#{buf.content.slice buf.pos}"
            repaint!
            changePos buf.pos - 1
        # Control + Backspace
        case '\b'
          r = /[^\w]*[\w]*/gy
            ..lastIndex = buf.content.length - buf.pos
          if r.test Array.from(buf.content).reverse!.join ''
            newPos = (buf.content.length - r.lastIndex) >? 0
          else
            newPos =  0
          buf.content = "#{buf.content.slice 0,newPos}#{buf.content.slice buf.pos}"
          changePos newPos
          repaint!
        # Delete
        case '\u001b[3~'
          buf.content = "#{buf.content.slice 0,buf.pos}#{buf.content.slice buf.pos+1}"
          repaint!
        # Control + Delete
        case '\u001b[3;5~'
          r = /[^\w]*[\w]*/gy
            ..lastIndex = buf.pos
          if r.test buf.content
            wordEnd = r.lastIndex <? buf.content.length
          else
            wordEnd = buf.content.length - 1
          buf.content = "#{buf.content.slice 0,buf.pos}#{buf.content.slice wordEnd}"
          repaint!
        # Enter
        case '\r'
          if buf.content.endsWith '\\' and buf.pos is buf.content.length
            changePos buf.pos - 1
            buf.content = "#{buf.content.slice 0 -1}\n"
            repaint!
            changePos buf.pos + 1
          else
            write '\n'
            try
              c = livescript.compile buf.content, {+bare, -header}
              global.require = require
              print vm.runInThisContext c
            catch e then log e
            if history.entries[*-1] isnt buf.content then history.entries.push buf.content
            history.pos = -1
            buf := content:'', pos:0 ; write "> "
        # Tab
        case '\t'
          [_,token] = buf.content.slice(0,buf.pos) is / *(.*)$/
          if (token is /(.*?)\.([^.]*)$/)? then [_,o0,o1] = token is /(.*?)\.([^.]*)$/
                                           else [_,o0,o1] = "global.#token" is /(.*?)\.([^.]*)$/
          try
            o = o0
            p = []
            try loop
              p.unshift Object.getOwnPropertyNames(vm.runInThisContext livescript.compile "#o", {+bare, -header}).filter((x) -> x.startsWith o1).sort!
              o += ".__proto__"
            catch e then
            p_flat = flatten p
            switch
              case p_flat.length is 1
                callback p_flat.0.slice o1.length
              case p_flat.length > 1
                for _p in p
                  maxlen = _p.reduce ((a,x) -> a >? x.length), 0
                  cols = Math.floor (process.stdout.columns+2) / (maxlen+2)
                  rows = []
                  let cs = cols, l = _p.length then while l > 0 then $ = Math.ceil l / cs-- ; l -= $ ; rows.push $
                  write '\n'
                  r = c = 0
                  for i from 0 to _p.length - 1
                    s = _p[r+rows.slice(0,c).reduce(((a,x)->a+x),0)]
                    write "#s#{{true:'\n',false:' '.repeat maxlen - s.length + 2}[c is cols-1]}"
                    if ++c is cols then [r,c] = [r+1,0]
                  write "\n"
                let pos = buf.pos
                  write "\n> " ; buf.pos = 0 ; repaint! ; changePos pos
                longestprefix = ''
                if p_flat.every((x)->x.startsWith p_flat.0) then longestprefix = p_flat.0
                else
                  while longestprefix isnt p_flat.0 and p_flat.every((x)->x.startsWith longestprefix)
                    longestprefix = p_flat.0.slice 0,longestprefix.length+1
                  longestprefix .= slice 0,-1
                callback longestprefix.slice o1.length
          catch e
            log e
            void
        # Control + C
        case '\u0003'
          log '^C'
          if buf.content.length > 0
            buf := content:'', pos:0 ; write "> "
            history.pos = -1
          else then exit!
        # Control + D
        case '\u0004' then exit!
        default
          buf.content = "#{buf.content.slice 0,buf.pos}#d#{buf.content.slice buf.pos}"
          repaint!
          changePos buf.pos + d.length
  log "Node #{process.version} Livescript v#{livescript.VERSION}"
  buf := content:'', pos:0 ; write "> "



exports <<< {absh}

if process.argv.1.endsWith 'absh.ls'
  help = -> console.log '''


    livescript repl implementation

    terminal usage: \u001b[1mabsh.ls\u001b[0m
    JS usage: \u001b[1mrequire("absh")(context)\u001b[0m

    '''
  if process.argv.2 in ["-h", "help", "-help", "--help"] then return help!

  i = 2
  let j = 3
    absh {j}
