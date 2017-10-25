#!/usr/bin/env node


// input validation

help = () => console.log(`
usage:

\x1b[1mablog start\x1b[0m port        starts logging server and
${ "" }           ${ "" }             web frontend

\x1b[1mablog pipe\x1b[0m name port    pipes stdin to tcp port
${ "" }          ${ "" }              using name and correct format
`)
a = process.argv
if(a[2] == "start"){
  if(isNaN(a[3]))
    return help()
}else if(a[2] == "pipe"){
  if(isNaN(a[4]))
    return help()
}else
  return help()


// process

if(a[2] == "start")
  require('./server').start(a[3])
if(a[2] == "pipe")
  require('./logpipe').pipe(a[3], a[4])
