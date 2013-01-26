
Array::__defineGetter__ 'head', -> @[0]
Array::__defineSetter__ 'head', (value) -> @[0] = value

Array::__defineGetter__ 'body', -> @[1..]
Array::__defineGetter__ 'filled', -> @length > 0

Array::__defineGetter__ 'last', -> @[@.length-1]
Array::__defineSetter__ 'last', (value) -> @[@.length-1] = value

Array::remove = (value) ->
  # log 'now', @
  self = @
  [1..@length].forEach ->
    thing = self.shift()
    unless thing is value
      self.push thing
  self

toType = (x) ->
  ret = ({}).toString.call(x).match /\s([a-zA-Z]+)/
  ret[1].toLowerCase()
arr$ = (x) -> (toType x) is 'array'
str$ = (x) -> (toType x) is 'string'
num$ = (x) -> (toType x) is 'number'
obj$ = (x) -> (toType x) is 'object'
fun$ = (x) -> (toType x) is 'function'

path = require 'path'
fs = require 'fs'
log = ->
  console.log '\n\n'
  console.log arguments...
util = require 'util'
puts = util.print

parser = require 'cirru-parser'

has_content = (list) -> list.length > 0

all_notes = []
process.on 'exit', -> log all_notes
note = ->
  log arguments
  for key, value of arguments
    unless value in all_notes
      all_notes.push value
  log arguments...

source_path = path.join process.env.PD, process.argv[2]
watching_files = []

# scopes are mainly for functions
scope_prototype =
  # outer scope is the scope the function runs
  outer: {}
  outer_set: (dest) -> @outer = dest
  outer_find: (key) ->
    if @outer.value[key]?
      @outer.value[key]
    else
      @outer.outer_find key

  # prototype, just like OOP
  proto: {}
  proto_set: (dest) -> @proto = dest
  proto_find: (key) ->
    if @value[key]?
      @value[key]
    else
      @proto.proto_find? key

  # the parent Node when an object assigned to another
  root: {}
  root_set: (dest) -> @root = dest
  root_find: (key) ->
    if @value[key]?
      @value[key]
    else
      @root.root_find? key

  # value and normal parent scopes
  parent: {}
  parent_set: (dest) -> @parent = dest
  value:
    '@': @proto
    '#': @outer
    '!': @parent
  value_set: (key, value) -> @value[key] = value
  value_find: (key) ->
    if @value[key]?
      @value[key]
    else
      @parent.parent_find? key

create_scope = (scope) ->
  child =
    __proto__: scope_prototype
    parent: scope
    proto: scope
    outer: scope
    root: scope

read = (table, scope) ->
  log 'reading::', table, scope

  head = scope.value_find table.head
  body = table.body
  log 'head:', table.head, head, body
  if arr$ head
    head = read head, scope
  if fun$ head
    head body, scope
  else
    if body.filled
      head[body]
    else
      head

boots =
  # echo prints anything passed to it
  echo: (body, scope) -> log body...

  # for [key], get one value from scope by 'key'
  get: (body, scope) ->
    key = body.head
    if arr$ key
      read key, scope
    else if num$ (Number key)
      # log 'number', key
      Number key
    else if str$ key
      scope.value_find key
    else
      throw new Error "Cant get #{key}"

  # set a key-value pair at scope.value
  set: (body, scope) ->
    log 'set started'
    key = body.shift()
    value_name = body.shift()
    scope.value_set key, (boots.get [value_name], scope)

  # read value by key and print them
  print: (body, scope) ->
    # log 'print started'
    log ''
    body.forEach (key) ->
      # log 'trying to print', key
      ret = boots.get [key], scope
      # log 'ret:: ', ret
      puts (JSON.stringify ret, null, 2)
      puts '\t'

  # generate string with JSON.stringify
  string: (body, scope) ->
    body.map(JSON.stringify).join ' '

  # get back string or an expression
  word: (body, scope) ->
    key = body.shift()
    if str$ key
      key
    else if arr$ key
      read key, scope
    else
      throw new throw "what could #{key} be?"

  # phrase: eval if there are arrays
  phrase: (body, scope) ->
    body.map((key) -> boots.word [key], scope).join ' '

  # generate list by reading from scope
  array: (body, scope) ->
    body.map((key) -> boots.get [key], scope)

  # a key-value map
  table: (body, scope) ->
    log 'createing table', body
    value = {}
    while body.head?
      pair = body.shift()
      key_name = pair.shift()
      value_name = pair.shift()
      key = boots.word [key_name], scope
      value[key] = boots.get [value_name], scope
    log 'table created:', value
    value

run = (source_filename) ->
  source = fs.readFileSync source_filename, 'utf8'

  {tree, code} = parser.parse source
  tree = tree.filter has_content
  log 'tree:', tree

  global_scope = create_scope {}
  global_scope.value = boots
  tree.forEach (line) -> read line, global_scope

  fs.unwatchFile source_filename
  fs.watchFile source_filename, interval: 100, ->
    run source_filename

log 'running'
run source_path