#!/usr/bin/env coffee

peg = require('pegjs')
fs = require('fs')
process = require('process')
_ = require('underscore')
color = require('kleur')
Tracer = require('pegjs-backtrace')
spawnSync = require('child_process').spawnSync
u = require('./utils')

ARGV = require('minimist')(process.argv.slice(2),
  strings: ['grep', 'node-type', 'hidden-paths']
  boolean: ['colored', 'debug', 'use-compiled']
  default: {
    colored: true
    debug: false
    grep: ""
    'hidden-paths': ""
    'use-compiled': false
    'node-type': ""
  }
)

options = [
  '_', 'colored', 'debug', 'grep',
  'hidden-paths', 'use-compiled',
  'node-type'
]

extra_options = _(_.keys(ARGV)).without(...options)

if _.any(extra_options) || ARGV._.length > 1
  u.error("unrecognized options #{extra_options.join(', ')}")
  u.error("\nUSAGE: parser [OPTIONS] INPUT")
  u.error("\n  options: #{options.join(', ')}")
  u.error("\n  defaults to stdin")
  process.exit(1)

ARGV.debug = true if ARGV.grep != "" || ARGV['node-type'] != ""

source = ARGV._.join(' ')

unless process.stdin.isTTY
  source += fs.readFileSync(0).toString().trim()

if fs.existsSync(source)
  source = fs.readFileSync(source, 'utf8')

hiddenPaths = ARGV['hidden-paths'].split(',').map((s) -> s.trim())
hiddenPaths = _.reject(hiddenPaths, (s) -> s == "")

tracer = new Tracer source,
  showFullPath: true,
  hiddenPaths: hiddenPaths
  matchesNode: (node, options) ->
    if options.grep != "" and not node.path.includes(options.grep)
      false
    else if options.nodeType != "" and node.type != options.nodeType
      false
    else
      true

if ARGV['use-compiled']
  if fs.existsSync('template.js')
    try
      Template = require('./template')
    catch exception
      u.error("parser is invalid\n")
      u.log(exception)
      process.exit(1)
  else
    u.error("template.js doesn't exist, you can compile it with --compile")
    process.exit(1)
else
  try
    Template = peg.generate(
      fs.readFileSync('template.pegjs', 'utf8')
      trace: true
    )
  catch exception
    u.error("parser can't be generated\n")
    u.error("#{exception.name}: #{exception.message}")
    process.exit(1)

matchOptions = {
  grep: ARGV.grep || ""
  nodeType: ARGV['node-type'] || ""
}

try
  result = Template.parse(source, tracer: tracer)
  u.log(tracer.getParseTreeString(matchOptions), colored: false) if ARGV.debug
  u.log(u.json(result))
catch exception
  throw exception unless exception.location

  u.log(tracer.getParseTreeString(matchOptions)) if ARGV.debug

  if exception.location.start.line
    u.log(source.split("\n")[exception.location.start.line - 1], colored: false)
  else
    u.log(source)

  start = exception.location.start
  end = exception.location.end

  u.error('^'.padStart(start.column, ' ').padEnd(end.column, '^')) if start
  u.error("#{exception.name}: at \"#{exception.found || ""}\" (#{exception.message})")

  process.exit(1)