#!/usr/bin/env node


// input validation

help = () => console.log(`
usage:

\x1b[1mablog start\x1b[0m port        starts logging server and
                                      web frontend

\x1b[1mablog pipe\x1b[0m name port    pipes stdin to udp port
                                      using name and correct format
`)
port = process.argv[2]
if(isNaN(port))
  return help()


switch(process.argv[3]){
  case "start":
    require('./server').start(port)
    break
  case "pipe":
    require('./logpipe').start(port)
}
