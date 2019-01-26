local inspect = require("inspect")
local keywords = {
   ["and"] = true,
   ["break"] = true,
   ["do"] = true,
   ["else"] = true,
   ["elseif"] = true,
   ["end"] = true,
   ["false"] = true,
   ["for"] = true,
   ["function"] = true,
   ["goto"] = true,
   ["if"] = true,
   ["in"] = true,
   ["local"] = true,
   ["nil"] = true,
   ["not"] = true,
   ["or"] = true,
   ["repeat"] = true,
   ["return"] = true,
   ["then"] = true,
   ["true"] = true,
   ["until"] = true,
   ["while"] = true,
}
local function lex(input)
   local tokens = {}
   local state = "any"
   local fwd = true
   local y = 1
   local x = 0
   local i = 0
   local function begin_token()
      table.insert(tokens, {
         ["x"] = x,
         ["y"] = y,
         ["i"] = i,
      })
   end
   local function drop_token()
      table.remove(tokens)
   end
   local function end_token(kind, t, last)
      assert(type(kind) == "string")
      local token = tokens[#tokens]
      token.tk = t or input:sub(token.i, last or i)
      if keywords[token.tk] then
         kind = "keyword"
      end
      token.kind = kind
   end
   while i <=#input do
      if fwd then
         i = i + 1
      end
      if i >#input then
         break
      end
      local c = input:sub(i, i)
      if fwd then
         if c == "\n" then
            y = y + 1
            x = 0
         else
            x = x + 1
         end
      else
         fwd = true
      end
      if state == "any" then
         if c == "-" then
            state = "maybecomment"
            begin_token()
         elseif c == "." then
            state = "maybedotdot"
            begin_token()
         elseif c == "\"" then
            state = "dblquote_string"
            begin_token()
         elseif c:match("[a-zA-Z_]") then
            state = "word"
            begin_token()
         elseif c:match("[0-9]") then
            state = "number"
            begin_token()
         elseif c:match("[<>=~]") then
            state = "maybeequals"
            begin_token()
         elseif c:match("[][(){},:#]") then
            begin_token()
            end_token(c)
         elseif c:match("[+*/]") then
            begin_token()
            end_token("op")
         end
      elseif state == "maybecomment" then
         if c == "-" then
            state = "comment"
            drop_token()
         else
            end_token("op", "-")
            fwd = false
            state = "any"
         end
      elseif state == "dblquote_string" then
         if c == "\\" then
            state = "escape_dblquote_string"
         elseif c == "\"" then
            end_token("string")
            state = "any"
         end
      elseif state == "escape_dblquote_string" then
         state = "dblquote_string"
      elseif state == "maybeequals" then
         if c == "=" then
            end_token("op")
            state = "any"
         else
            end_token("=", nil, i - 1)
            fwd = false
            state = "any"
         end
      elseif state == "maybedotdot" then
         if c == "." then
            end_token("op")
            state = "maybedotdotdot"
         else
            end_token(".", nil, i - 1)
            fwd = false
            state = "any"
         end
      elseif state == "maybedotdotdot" then
         if c == "." then
            end_token("...")
            state = "any"
         else
            end_token("op", nil, i - 1)
            fwd = false
            state = "any"
         end
      elseif state == "comment" then
         if c == "\n" then
            state = "any"
         end
      elseif state == "word" then
         if not c:match("[a-zA-Z0-9_]") then
            end_token("word", nil, i - 1)
            fwd = false
            state = "any"
         end
      elseif state == "number" then
         if not c:match("[0-9]") then
            end_token("number", nil, i - 1)
            fwd = false
            state = "any"
         end
      end
   end
   return tokens
end
local add_space = {
   ["word:keyword"] = true,
   ["word:word"] = true,
   ["word:string"] = true,
   ["word:="] = true,
   ["word:op"] = true,
   ["keyword:word"] = true,
   ["keyword:keyword"] = true,
   ["keyword:string"] = true,
   ["keyword:="] = true,
   ["keyword:op"] = true,
   ["=:word"] = true,
   ["=:keyword"] = true,
   ["=:string"] = true,
   ["=:number"] = true,
   ["=:{"] = true,
   ["=:("] = true,
   [",:word"] = true,
   [",:keyword"] = true,
   [",:string"] = true,
   [",:{"] = true,
   ["):op"] = true,
   ["):word"] = true,
   ["):keyword"] = true,
   ["keyword:("] = true,
   ["op:string"] = true,
   ["op:number"] = true,
   ["op:word"] = true,
   ["op:keyword"] = true,
   ["]:word"] = true,
   ["]:keyword"] = true,
   ["]:="] = true,
   ["string:op"] = true,
   ["string:word"] = true,
   ["string:keyword"] = true,
   ["number:word"] = true,
   ["number:keyword"] = true,
}
local should_unindent = {
   ["end"] = true,
   ["elseif"] = true,
   ["else"] = true,
   ["}"] = true,
}
local should_indent = {
   ["for"] = true,
   ["if"] = true,
   ["while"] = true,
   ["elseif"] = true,
   ["else"] = true,
}
local function pretty_print_tokens(tokens)
   local y = 1
   local out = {}
   local kind = nil
   local indent = 0
   local bracket = false
   for _, t in ipairs(tokens) do
      while t.y > y do
         if bracket then
            indent = indent + 1
            bracket = false
         end
         table.insert(out, "\n")
         y = y + 1
         kind = nil
      end
      if kind == nil then
         if should_unindent[t.tk] then
            indent = indent - 1
         end
         if indent < 0 then
            indent = 0
         end
         for _ = 1, indent do
            table.insert(out, "   ")
         end
         if should_indent[t.tk] or t.tk == "local" and tokens[_ + 1].tk == "function" then
            indent = indent + 1
         end
      end
      if add_space[(kind or "") .. ":" .. t.kind] then
         table.insert(out, " ")
      end
      table.insert(out, t.tk)
      kind = t.kind
      bracket = t.tk == "{"
   end
   return table.concat(out)
end
local parse_expression
local parse_statements
local parse_argument_list
local function fail(tokens, i, errs)
   local tks = {}
   for x = i, i + 10 do
      if tokens[x] then
         table.insert(tks, tokens[x].tk)
      end
   end
   table.insert(errs, {
      ["y"] = tokens[i].y,
      ["x"] = tokens[i].x,
      ["msg"] = table.concat(tks, " ") .. debug.traceback(),
   })
   return i + 1
end
local function verify_tk(tokens, i, errs, tk)
   if tokens[i].tk == tk then
      return i + 1
   end
   return fail(tokens, i, errs)
end
local function new_node(tokens, i, kind)
   local t = tokens[i]
   return{
      ["y"] = t.y,
      ["x"] = t.x,
      ["tk"] = t.tk,
      ["kind"] = kind or t.kind,
   }
end
local function verify_kind(tokens, i, errs, kind, node_kind)
   if tokens[i].kind == kind then
      return i + 1, new_node(tokens, i, node_kind)
   end
   return fail(tokens, i, errs)
end
local function parse_table_item(tokens, i, errs, n)
   local node = new_node(tokens, i, "table_item")
   if tokens[i].tk == "[" then
      i = i + 1
      i, node.key = parse_expression(tokens, i, errs)
      i = verify_tk(tokens, i, errs, "]")
      i = verify_tk(tokens, i, errs, "=")
      i, node.value = parse_expression(tokens, i, errs)
      return i, node, n
   elseif tokens[i].kind == "word" and tokens[i + 1].tk == "=" then
      i, node.key = verify_kind(tokens, i, errs, "word", "string")
      node.key.tk = "\"" .. node.key.tk .. "\""
      i = verify_tk(tokens, i, errs, "=")
      i, node.value = parse_expression(tokens, i, errs)
      return i, node, n
   else
      node.key = new_node(tokens, i, "number")
      node.key.tk = n
      i, node.value = parse_expression(tokens, i, errs)
      return i, node, n + 1
   end
end
local function parse_list(tokens, i, errs, node, close, is_sep, parse_item)
   if type(close) == "string" then
      close = {
         [close] = true,
      }
   end
   local n = 1
   while tokens[i] do
      if close[tokens[i].tk] then
         break
      end
      local item
      i, item, n = parse_item(tokens, i, errs, n)
      table.insert(node, item)
      if tokens[i] and tokens[i].tk == "," then
         i = i + 1
         if is_sep and tokens[i].tk == close then
            return fail(tokens, i, errs)
         end
      end
   end
   return i, node
end
local function parse_bracket_list(tokens, i, errs, node_kind, open, close, is_sep, parse_item)
   local node = new_node(tokens, i, node_kind)
   i = verify_tk(tokens, i, errs, open)
   i = parse_list(tokens, i, errs, node, close, is_sep, parse_item)
   i = i + 1
   return i, node
end
local function parse_table_literal(tokens, i, errs)
   return parse_bracket_list(tokens, i, errs, "table_literal", "{", "}", false, parse_table_item)
end
local function parse_literal(tokens, i, errs)
   if tokens[i].tk == "{" then
      return parse_table_literal(tokens, i, errs)
   elseif tokens[i].kind == "..." then
      return verify_kind(tokens, i, errs, "...")
   elseif tokens[i].kind == "string" then
      return verify_kind(tokens, i, errs, "string")
   elseif tokens[i].kind == "word" then
      return verify_kind(tokens, i, errs, "word", "variable")
   elseif tokens[i].kind == "number" then
      return verify_kind(tokens, i, errs, "number")
   elseif tokens[i].tk == "true" then
      return verify_kind(tokens, i, errs, "keyword", "boolean")
   elseif tokens[i].tk == "false" then
      return verify_kind(tokens, i, errs, "keyword", "boolean")
   elseif tokens[i].tk == "nil" then
      return verify_kind(tokens, i, errs, "keyword", "nil")
   elseif tokens[i].tk == "function" then
      local node = new_node(tokens, i, "function")
      i = verify_tk(tokens, i, errs, "function")
      i, node.args = parse_argument_list(tokens, i, errs)
      i, node.body = parse_statements(tokens, i, errs)
      i = verify_tk(tokens, i, errs, "end")
      return i, node
   end
   return fail(tokens, i, errs)
end
do
local precedences = {
   [1] = {
      ["not"] = 11,
      ["#"] = 11,
      ["-"] = 11,
      ["~"] = 11,
   },
   [2] = {
      ["or"] = 1,
      ["and"] = 2,
      ["<"] = 3,
      [">"] = 3,
      ["<="] = 3,
      [">="] = 3,
      ["~="] = 3,
      ["=="] = 3,
      ["|"] = 4,
      ["~"] = 5,
      ["&"] = 6,
      ["<<"] = 7,
      [">>"] = 7,
      [".."] = 8,
      ["+"] = 8,
      ["-"] = 9,
      ["*"] = 10,
      ["/"] = 10,
      ["//"] = 10,
      ["%"] = 10,
      ["^"] = 12,
      ["@funcall"] = 100,
      ["@index"] = 200,
      ["."] = 200,
      [":"] = 200,
   },
}
local function is_unop(token)
   return precedences[1][token.tk]~= nil
end
local function is_binop(token)
   return precedences[2][token.tk]~= nil
end
local function prec(op)
   if op == "sentinel" then
      return - 9999
   end
   return precedences[op.arity][op.op]
end
local function pop_operator(operators, operands)
   if operators[#operators].arity == 2 then
      local t2 = table.remove(operands)
      local t1 = table.remove(operands)
      table.insert(operands, {
         ["y"] = t1.y,
         ["x"] = t1.x,
         ["kind"] = "op",
         ["op"] = table.remove(operators),
         ["e1"] = t1,
         ["e2"] = t2,
      })
   else
      local t1 = table.remove(operands)
      table.insert(operands, {
         ["y"] = t1.y,
         ["x"] = t1.x,
         ["kind"] = "op",
         ["op"] = table.remove(operators),
         ["e1"] = t1,
      })
   end
end
local function push_operator(op, operators, operands)
   while prec(operators[#operators]) >= prec(op) do
      pop_operator(operators, operands)
   end
   op.prec = assert(precedences[op.arity][op.op])
   table.insert(operators, op)
end
local P
local E
P = function (tokens, i, errs, operators, operands)
if is_unop(tokens[i]) then
   push_operator({
      ["y"] = tokens[i].y,
      ["x"] = tokens[i].x,
      ["arity"] = 1,
      ["op"] = tokens[i].tk,
   }, operators, operands)
   i = i + 1
   i = P(tokens, i, errs, operators, operands)
   return i
elseif tokens[i].tk == "(" then
   i = i + 1
   table.insert(operators, "sentinel")
   i = E(tokens, i, errs, operators, operands)
   i = verify_tk(tokens, i, errs, ")")
   table.remove(operators)
   return i
else
   local leaf
   i, leaf = parse_literal(tokens, i, errs)
   if leaf then
      table.insert(operands, leaf)
   end
   return i
end
end
local function push_arguments(tokens, i, errs, operands)
   local args
   i, args = parse_bracket_list(tokens, i, errs, "expression_list", "(", ")", true, parse_expression)
   table.insert(operands, args)
   return i
end
local function push_index(tokens, i, errs, operands)
   local arg
   i = verify_tk(tokens, i, errs, "[")
   i, arg = parse_expression(tokens, i, errs)
   i = verify_tk(tokens, i, errs, "]")
   table.insert(operands, arg)
   return i
end
E = function (tokens, i, errs, operators, operands)
i = P(tokens, i, errs, operators, operands)
while tokens[i] do
   if tokens[i].kind == "string" or tokens[i].kind == "{" then
      push_operator({
         ["y"] = tokens[i].y,
         ["x"] = tokens[i].x,
         ["arity"] = 2,
         ["op"] = "@funcall",
      }, operators, operands)
      local arglist = new_node(tokens, i, "argument_list")
      local arg
      if tokens[i].kind == "string" then
         arg = new_node(tokens, i)
         i = i + 1
      else
         i, arg = parse_table_literal(tokens, i, errs)
      end
      table.insert(arglist, arg)
      table.insert(operands, arglist)
   elseif tokens[i].tk == "(" then
      push_operator({
         ["y"] = tokens[i].y,
         ["x"] = tokens[i].x,
         ["arity"] = 2,
         ["op"] = "@funcall",
      }, operators, operands)
      i = push_arguments(tokens, i, errs, operands)
   elseif tokens[i].tk == "[" then
      push_operator({
         ["y"] = tokens[i].y,
         ["x"] = tokens[i].x,
         ["arity"] = 2,
         ["op"] = "@index",
      }, operators, operands)
      i = push_index(tokens, i, errs, operands)
   elseif is_binop(tokens[i]) then
      push_operator({
         ["y"] = tokens[i].y,
         ["x"] = tokens[i].x,
         ["arity"] = 2,
         ["op"] = tokens[i].tk,
      }, operators, operands)
      i = i + 1
      i = P(tokens, i, errs, operators, operands)
   else
      break
   end
end
while operators[#operators]~= "sentinel" do
   pop_operator(operators, operands)
end
return i
end
parse_expression = function (tokens, i, errs)
local operands = {}
local operators = {}
table.insert(operators, "sentinel")
i = E(tokens, i, errs, operators, operands)
return i, operands[#operands]
end
end
local function parse_variable(tokens, i, errs)
   if tokens[i].tk == "..." then
      return verify_kind(tokens, i, errs, "...")
   end
   return verify_kind(tokens, i, errs, "word", "variable")
end
parse_argument_list = function (tokens, i, errs)
return parse_bracket_list(tokens, i, errs, "argument_list", "(", ")", true, parse_variable)
end
local function parse_local_function(tokens, i, errs)
   local node = new_node(tokens, i, "local_function")
   i = verify_tk(tokens, i, errs, "local")
   i = verify_tk(tokens, i, errs, "function")
   i, node.name = verify_kind(tokens, i, errs, "word")
   i, node.args = parse_argument_list(tokens, i, errs)
   i, node.body = parse_statements(tokens, i, errs)
   i = verify_tk(tokens, i, errs, "end")
   return i, node
end
local function parse_global_function(tokens, i, errs)
   local node = new_node(tokens, i, "global_function")
   i = verify_tk(tokens, i, errs, "function")
   i, node.name = verify_kind(tokens, i, errs, "word")
   i, node.args = parse_argument_list(tokens, i, errs)
   i, node.body = parse_statements(tokens, i, errs)
   i = verify_tk(tokens, i, errs, "end")
   return i, node
end
local function parse_if(tokens, i, errs)
   local node = new_node(tokens, i, "if")
   i = verify_tk(tokens, i, errs, "if")
   i, node.exp = parse_expression(tokens, i, errs)
   i = verify_tk(tokens, i, errs, "then")
   i, node.thenpart = parse_statements(tokens, i, errs)
   node.elseifs = {}
   while tokens[i].tk == "elseif" do
      i = i + 1
      local subnode = new_node(tokens, i, "elseif")
      i, subnode.exp = parse_expression(tokens, i, errs)
      i = verify_tk(tokens, i, errs, "then")
      i, subnode.thenpart = parse_statements(tokens, i, errs)
      table.insert(node.elseifs, subnode)
   end
   if tokens[i].tk == "else" then
      i = i + 1
      i, node.elsepart = parse_statements(tokens, i, errs)
   end
   i = verify_tk(tokens, i, errs, "end")
   return i, node
end
local function parse_while(tokens, i, errs)
   local node = new_node(tokens, i, "while")
   i = verify_tk(tokens, i, errs, "while")
   i, node.exp = parse_expression(tokens, i, errs)
   i = verify_tk(tokens, i, errs, "do")
   i, node.body = parse_statements(tokens, i, errs)
   i = verify_tk(tokens, i, errs, "end")
   return i, node
end
local function parse_fornum(tokens, i, errs)
   local node = new_node(tokens, i, "fornum")
   i = i + 1
   i, node.var = verify_kind(tokens, i, errs, "word", "variable")
   i = verify_tk(tokens, i, errs, "=")
   i, node.from = parse_expression(tokens, i, errs)
   i = verify_tk(tokens, i, errs, ",")
   i, node.to = parse_expression(tokens, i, errs)
   if tokens[i].tk == "," then
      i = i + 1
      i, node.step = parse_expression(tokens, i, errs)
   end
   i = verify_tk(tokens, i, errs, "do")
   i, node.body = parse_statements(tokens, i, errs)
   i = verify_tk(tokens, i, errs, "end")
   return i, node
end
local function parse_forin(tokens, i, errs)
   local node = new_node(tokens, i, "forin")
   i = i + 1
   node.vars = new_node(tokens, i, "variables")
   i, node.vars = parse_list(tokens, i, errs, node.vars, "in", true, parse_variable)
   i = verify_tk(tokens, i, errs, "in")
   i, node.exp = parse_expression(tokens, i, errs)
   i = verify_tk(tokens, i, errs, "do")
   i, node.body = parse_statements(tokens, i, errs)
   i = verify_tk(tokens, i, errs, "end")
   return i, node
end
local function parse_for(tokens, i, errs)
   if tokens[i + 2].tk == "=" then
      return parse_fornum(tokens, i, errs)
   else
      return parse_forin(tokens, i, errs)
   end
end
local function parse_repeat(tokens, i, errs)
   local node = new_node(tokens, i, "repeat")
   i = verify_tk(tokens, i, errs, "repeat")
   i, node.body = parse_statements(tokens, i, errs)
   i = verify_tk(tokens, i, errs, "until")
   i, node.exp = parse_expression(tokens, i, errs)
   return i, node
end
local function parse_do(tokens, i, errs)
   local node = new_node(tokens, i, "do")
   i = verify_tk(tokens, i, errs, "do")
   i, node.body = parse_statements(tokens, i, errs)
   i = verify_tk(tokens, i, errs, "end")
   return i, node
end
local function parse_break(tokens, i, errs)
   local node = new_node(tokens, i, "break")
   i = verify_tk(tokens, i, errs, "break")
   return i, node
end
local stop_statement_list = {
   ["end"] = true,
   ["else"] = true,
   ["elseif"] = true,
   ["until"] = true,
}
local function parse_return(tokens, i, errs)
   local node = new_node(tokens, i, "return")
   i = verify_tk(tokens, i, errs, "return")
   node.exps = new_node(tokens, i, "expression_list")
   i = parse_list(tokens, i, errs, node.exps, stop_statement_list, true, parse_expression)
   return i, node
end
local function parse_call_or_assignment(tokens, i, errs, is_local)
   local asgn = new_node(tokens, i, "assignment")
   if is_local then
      asgn.kind = "local_declaration"
   end
   local lhs
   i, lhs = parse_expression(tokens, i, errs)
   assert(lhs)
   asgn.vars = new_node(tokens, i, "variables")
   table.insert(asgn.vars, lhs)
   if tokens[i].tk == "," then
      while tokens[i].tk == "," do
         i = i + 1
         local var
         i, var = parse_expression(tokens, i, errs)
         table.insert(asgn.vars, var)
      end
   end
   if tokens[i].tk == "=" then
      asgn.vals = new_node(tokens, i, "values")
      repeat
      i = i + 1
      local val
      i, val = parse_expression(tokens, i, errs)
      table.insert(asgn.vals, val)
      until not tokens[i] or tokens[i].tk ~= ","
      return i, asgn
   elseif is_local then
      return i, asgn
   end
   if lhs.op and lhs.op.op == "@funcall" then
      return i, lhs
   end
   return fail(tokens, i, errs)
end
local function parse_statement(tokens, i, errs)
   if tokens[i].tk == "local" then
      if tokens[i + 1].tk == "function" then
         return parse_local_function(tokens, i, errs)
      else
         i = i + 1
         return parse_call_or_assignment(tokens, i, errs, true)
      end
   elseif tokens[i].tk == "function" then
      return parse_global_function(tokens, i, errs)
   elseif tokens[i].tk == "if" then
      return parse_if(tokens, i, errs)
   elseif tokens[i].tk == "while" then
      return parse_while(tokens, i, errs)
   elseif tokens[i].tk == "repeat" then
      return parse_repeat(tokens, i, errs)
   elseif tokens[i].tk == "for" then
      return parse_for(tokens, i, errs)
   elseif tokens[i].tk == "do" then
      return parse_do(tokens, i, errs)
   elseif tokens[i].tk == "break" then
      return parse_break(tokens, i, errs)
   elseif tokens[i].tk == "return" then
      return parse_return(tokens, i, errs)
   elseif tokens[i].kind == "word" then
      return parse_call_or_assignment(tokens, i, errs, false)
   end
   return fail(tokens, i, errs)
end
parse_statements = function (tokens, i, errs)
local node = new_node(tokens, i, "statements")
while tokens[i] do
   if stop_statement_list[tokens[i].tk] then
      break
   end
   local item
   i, item = parse_statement(tokens, i, errs)
   if not item then
      break
   end
   table.insert(node, item)
end
return i, node
end
local function parse_program(tokens, errs)
   return parse_statements(tokens,1, errs)
end
local function recurse_ast(ast, visitor)
   assert(visitor[ast.kind])
   if visitor["@beforebefore"] then
      visitor["@beforebefore"](ast)
   end
   if visitor[ast.kind].before then
      visitor[ast.kind].before(ast)
   end
   if visitor["@afterbefore"] then
      visitor["@afterbefore"](ast)
   end
   local xs = {}
   if ast.kind == "statements" or ast.kind == "variables" or ast.kind == "values" or ast.kind == "argument_list" or ast.kind == "expression_list" or ast.kind == "table_literal" then
      for _, child in ipairs(ast) do
         table.insert(xs, recurse_ast(child, visitor) or false)
      end
   elseif ast.kind == "local_declaration" or ast.kind == "assignment" then
      table.insert(xs, recurse_ast(ast.vars, visitor) or false)
      if ast.vals then
         table.insert(xs, recurse_ast(ast.vals, visitor) or false)
      end
   elseif ast.kind == "table_item" then
      table.insert(xs, recurse_ast(ast.key, visitor) or false)
      table.insert(xs, recurse_ast(ast.value, visitor) or false)
   elseif ast.kind == "if" then
      table.insert(xs, recurse_ast(ast.exp, visitor) or false)
      table.insert(xs, recurse_ast(ast.thenpart, visitor) or false)
      local elseifs = {}
      for _, e in ipairs(ast.elseifs) do
         table.insert(elseifs, recurse_ast(e, visitor) or false)
      end
      table.insert(xs, elseifs)
      if ast.elsepart then
         table.insert(xs, recurse_ast(ast.elsepart, visitor) or false)
      end
   elseif ast.kind == "while" then
      table.insert(xs, recurse_ast(ast.exp, visitor) or false)
      table.insert(xs, recurse_ast(ast.body, visitor) or false)
   elseif ast.kind == "repeat" then
      table.insert(xs, recurse_ast(ast.body, visitor) or false)
      table.insert(xs, recurse_ast(ast.exp, visitor) or false)
   elseif ast.kind == "function" then
      table.insert(xs, recurse_ast(ast.args, visitor) or false)
      table.insert(xs, recurse_ast(ast.body, visitor) or false)
   elseif ast.kind == "forin" then
      table.insert(xs, recurse_ast(ast.vars, visitor) or false)
      table.insert(xs, recurse_ast(ast.exp, visitor) or false)
      table.insert(xs, recurse_ast(ast.body, visitor) or false)
   elseif ast.kind == "fornum" then
      table.insert(xs, recurse_ast(ast.var, visitor) or false)
      table.insert(xs, recurse_ast(ast.from, visitor) or false)
      table.insert(xs, recurse_ast(ast.to, visitor) or false)
      table.insert(xs, ast.step and recurse_ast(ast.step, visitor) or false)
      table.insert(xs, recurse_ast(ast.body, visitor) or false)
   elseif ast.kind == "elseif" then
      table.insert(xs, recurse_ast(ast.exp, visitor) or false)
      table.insert(xs, recurse_ast(ast.thenpart, visitor) or false)
   elseif ast.kind == "return" then
      table.insert(xs, recurse_ast(ast.exps, visitor) or false)
   elseif ast.kind == "do" then
      table.insert(xs, recurse_ast(ast.body, visitor) or false)
   elseif ast.kind == "local_function" or ast.kind == "global_function" then
      table.insert(xs, recurse_ast(ast.name, visitor) or false)
      table.insert(xs, recurse_ast(ast.args, visitor) or false)
      table.insert(xs, recurse_ast(ast.body, visitor) or false)
   elseif ast.kind == "op" then
      table.insert(xs, recurse_ast(ast.e1, visitor) or false)
      local p1 = ast.e1.op and ast.e1.op.prec or false
      if ast.op.op == ":" and ast.e1.kind == "string" then
         p1 =- 999
      end
      table.insert(xs, p1)
      if ast.op.arity == 2 then
         table.insert(xs, recurse_ast(ast.e2, visitor) or false)
         table.insert(xs, ast.e2.op and ast.e2.op.prec or false)
      end
   elseif ast.kind == "variable" or ast.kind == "word" or ast.kind == "string" or ast.kind == "number" or ast.kind == "break" or ast.kind == "nil" or ast.kind == "..." or ast.kind == "boolean" then

   else
      if not ast.kind then
         error("wat: " .. inspect(ast))
      end
      error("unknown node kind " .. ast.kind)
   end
   if visitor["@beforeafter"] then
      visitor["@beforeafter"](ast, xs)
   end
   local ret = visitor[ast.kind].after(ast, xs)
   if visitor["@afterafter"] then
      ret = visitor["@afterafter"](ast, xs, ret)
   end
   return ret
end
local tight_op = {
   ["."] = true,
   [":"] = true,
   ["-"] = true,
   ["~"] = true,
   ["#"] = true,
}
local spaced_op = {
   ["not"] = true,
   ["or"] = true,
   ["and"] = true,
   ["<"] = true,
   [">"] = true,
   ["<="] = true,
   [">="] = true,
   ["~="] = true,
   ["=="] = true,
   ["|"] = true,
   ["~"] = true,
   ["&"] = true,
   ["<<"] = true,
   [">>"] = true,
   [".."] = true,
   ["+"] = true,
   ["-"] = true,
   ["*"] = true,
   ["/"] = true,
   ["//"] = true,
   ["%"] = true,
   ["^"] = true,
}
local function pretty_print_ast(ast)
   local indent = 0
   local visit = {
      ["statements"] = {
         ["after"] = function (node, children)
         local out = {}
         for _, child in ipairs(children) do
            table.insert(out,("   "):rep(indent))
            table.insert(out, child)
            table.insert(out, "\n")
         end
         if#children == 0 then
            table.insert(out, "\n")
         end
         return table.concat(out)
      end,
   },
   ["local_declaration"] = {
      ["after"] = function (node, children)
      local out = {}
      table.insert(out, "local ")
      table.insert(out, children[1])
      if children[2] then
         table.insert(out, " = ")
         table.insert(out, children[2])
      end
      return table.concat(out)
   end,
},
["assignment"] = {
   ["after"] = function (node, children)
   local out = {}
   table.insert(out, children[1])
   table.insert(out, " = ")
   table.insert(out, children[2])
   return table.concat(out)
end,
},
["if"] = {
   ["before"] = function ()
   indent = indent + 1
end,
["after"] = function (node, children)
local out = {}
table.insert(out, "if ")
table.insert(out, children[1])
table.insert(out, " then\n")
table.insert(out, children[2])
indent = indent - 1
for _, e in ipairs(children[3]) do
   table.insert(out,("   "):rep(indent))
   table.insert(out, "elseif ")
   table.insert(out, e)
end
if children[4] then
   table.insert(out,("   "):rep(indent))
   table.insert(out, "else\n")
   table.insert(out, children[4])
end
table.insert(out,("   "):rep(indent))
table.insert(out, "end")
return table.concat(out)
end,
},
["while"] = {
   ["before"] = function ()
   indent = indent + 1
end,
["after"] = function (node, children)
local out = {}
table.insert(out, "while ")
table.insert(out, children[1])
table.insert(out, " do\n")
table.insert(out, children[2])
indent = indent - 1
table.insert(out,("   "):rep(indent))
table.insert(out, "end")
return table.concat(out)
end,
},
["repeat"] = {
   ["before"] = function ()
   indent = indent + 1
end,
["after"] = function (node, children)
local out = {}
table.insert(out, "repeat\n")
table.insert(out, children[1])
indent = indent - 1
table.insert(out,("   "):rep(indent))
table.insert(out, "until ")
table.insert(out, children[2])
return table.concat(out)
end,
},
["do"] = {
   ["before"] = function ()
   indent = indent + 1
end,
["after"] = function (node, children)
local out = {}
table.insert(out, "do\n")
table.insert(out, children[1])
indent = indent - 1
table.insert(out,("   "):rep(indent))
table.insert(out, "end")
return table.concat(out)
end,
},
["forin"] = {
   ["before"] = function ()
   indent = indent + 1
end,
["after"] = function (node, children)
local out = {}
table.insert(out, "for ")
table.insert(out, children[1])
table.insert(out, " in ")
table.insert(out, children[2])
table.insert(out, " do\n")
table.insert(out, children[3])
indent = indent - 1
table.insert(out,("   "):rep(indent))
table.insert(out, "end")
return table.concat(out)
end,
},
["fornum"] = {
   ["before"] = function ()
   indent = indent + 1
end,
["after"] = function (node, children)
local out = {}
table.insert(out, "for ")
table.insert(out, children[1])
table.insert(out, " = ")
table.insert(out, children[2])
table.insert(out, ", ")
table.insert(out, children[3])
if children[4] then
   table.insert(out, ", ")
   table.insert(out, children[4])
end
table.insert(out, " do\n")
table.insert(out, children[5])
indent = indent - 1
table.insert(out,("   "):rep(indent))
table.insert(out, "end")
return table.concat(out)
end,
},
["return"] = {
   ["after"] = function (node, children)
   local out = {}
   table.insert(out, "return ")
   table.insert(out, children[1])
   return table.concat(out)
end,
},
["break"] = {
   ["after"] = function (node, children)
   local out = {}
   table.insert(out, "break")
   return table.concat(out)
end,
},
["elseif"] = {
   ["after"] = function (node, children)
   local out = {}
   table.insert(out, children[1])
   table.insert(out, " then\n")
   table.insert(out, children[2])
   return table.concat(out)
end,
},
["variables"] = {
   ["after"] = function (node, children)
   local out = {}
   for i, child in ipairs(children) do
      if i > 1 then
         table.insert(out, ", ")
      end
      table.insert(out, tostring(child))
   end
   return table.concat(out)
end,
},
["table_literal"] = {
   ["before"] = function ()
   indent = indent + 1
end,
["after"] = function (node, children)
local out = {}
if#children == 0 then
   indent = indent - 1
   return "{}"
end
table.insert(out, "{\n")
for _, child in ipairs(children) do
   table.insert(out,("   "):rep(indent))
   table.insert(out, child)
   table.insert(out, "\n")
end
indent = indent - 1
table.insert(out,("   "):rep(indent))
table.insert(out, "}")
return table.concat(out)
end,
},
["table_item"] = {
   ["after"] = function (node, children)
   local out = {}
   table.insert(out, "[")
   table.insert(out, children[1])
   table.insert(out, "] = ")
   table.insert(out, children[2])
   table.insert(out, ", ")
   return table.concat(out)
end,
},
["local_function"] = {
   ["before"] = function ()
   indent = indent + 1
end,
["after"] = function (node, children)
local out = {}
table.insert(out, "local function ")
table.insert(out, children[1])
table.insert(out, "(")
table.insert(out, children[2])
table.insert(out, ")\n")
table.insert(out, children[3])
indent = indent - 1
table.insert(out,("   "):rep(indent))
table.insert(out, "end")
return table.concat(out)
end,
},
["global_function"] = {
   ["before"] = function ()
   indent = indent + 1
end,
["after"] = function (node, children)
local out = {}
table.insert(out, "function ")
table.insert(out, children[1])
table.insert(out, "(")
table.insert(out, children[2])
table.insert(out, ")\n")
table.insert(out, children[3])
indent = indent - 1
table.insert(out,("   "):rep(indent))
table.insert(out, "end")
return table.concat(out)
end,
},
["function"] = {
   ["before"] = function ()
   indent = indent + 1
end,
["after"] = function (node, children)
local out = {}
table.insert(out, "function(")
table.insert(out, children[1])
table.insert(out, ")\n")
table.insert(out, children[2])
indent = indent - 1
table.insert(out,("   "):rep(indent))
table.insert(out, "end")
return table.concat(out)
end,
},
["op"] = {
   ["after"] = function (node, children)
   local out = {}
   if node.op.op == "@funcall" then
      table.insert(out, children[1])
      table.insert(out, "(")
      table.insert(out, children[3])
      table.insert(out, ")")
   elseif node.op.op == "@index" then
      table.insert(out, children[1])
      table.insert(out, "[")
      table.insert(out, children[3])
      table.insert(out, "]")
   elseif tight_op[node.op.op] or spaced_op[node.op.op] then
      if node.op.arity == 1 then
         table.insert(out, node.op.op)
         if spaced_op[node.op.op] then
            table.insert(out, " ")
         end
      end
      if children[2] and node.op.prec > children[2] then
         table.insert(out, "(")
      end
      table.insert(out, children[1])
      if children[2] and node.op.prec > children[2] then
         table.insert(out, ")")
      end
      if node.op.arity == 2 then
         if spaced_op[node.op.op] then
            table.insert(out, " ")
         end
         table.insert(out, node.op.op)
         if spaced_op[node.op.op] then
            table.insert(out, " ")
         end
         if children[4] and node.op.prec > children[4] then
            table.insert(out, "(")
         end
         table.insert(out, children[3])
         if children[4] and node.op.prec > children[4] then
            table.insert(out, ")")
         end
      end
   else
      error("unknown node op " .. node.op.op)
   end
   return table.concat(out)
end,
},
["variable"] = {
   ["after"] = function (node, children)
   local out = {}
   table.insert(out, node.tk)
   return table.concat(out)
end,
},
}
visit["values"] = visit["variables"]
visit["expression_list"] = visit["variables"]
visit["argument_list"] = visit["variables"]
visit["word"] = visit["variable"]
visit["string"] = visit["variable"]
visit["number"] = visit["variable"]
visit["nil"] = visit["variable"]
visit["boolean"] = visit["variable"]
visit["..."] = visit["variable"]
return recurse_ast(ast, visit)
end
local ANY = {
   ["typename"] = "any",
}
local NIL = {
   ["typename"] = "nil",
}
local TABLE = {
   ["typename"] = "table",
}
local NUMBER = {
   ["typename"] = "number",
}
local STRING = {
   ["typename"] = "string",
}
local BOOLEAN = {
   ["typename"] = "boolean",
}
local INVALID = {
   ["typename"] = "invalid",
}
local numeric_binop = {
   [2] = {
      ["number"] = {
         ["number"] = NUMBER,
      },
   },
}
local relational_binop = {
   [2] = {
      ["number"] = {
         ["number"] = BOOLEAN,
      },
      ["string"] = {
         ["string"] = BOOLEAN,
      },
   },
}
local boolean_binop = {
   [2] = {
      ["boolean"] = {
         ["boolean"] = BOOLEAN,
      },
   },
}
local op_types = {
   ["#"] = {
      [1] = {
         ["string"] = NUMBER,
         ["table"] = NUMBER,
      },
   },
   ["."] = {
      [2] = {},
   },
   [":"] = {
      [2] = {},
   },
   ["+"] = numeric_binop,
   ["-"] = {
      [1] = {
         ["number"] = NUMBER,
      },
      [2] = {
         ["number"] = {
            ["number"] = NUMBER,
         },
      },
   },
   ["*"] = numeric_binop,
   ["/"] = numeric_binop,
   ["~="] = relational_binop,
   ["=="] = relational_binop,
   ["<="] = relational_binop,
   [">="] = relational_binop,
   ["<"] = relational_binop,
   [">"] = relational_binop,
   ["not"] = {
      [1] = {
         ["boolean"] = BOOLEAN,
      },
   },
   ["or"] = boolean_binop,
   ["and"] = boolean_binop,
   [".."] = {
      [2] = {
         ["string"] = {
            ["string"] = STRING,
         },
      },
   },
}
local function type_check(ast)
   local st = {
      [1] = {
         ["require"] = {
            ["typename"] = "function",
            ["args"] = {
               [1] = STRING,
            },
            ["rets"] = {},
         },
         ["table"] = {
            ["typename"] = "table",
            ["fields"] = {
               ["insert"] = {
                  ["typename"] = "poly",
                  [1] = {
                     ["typename"] = "function",
                     ["args"] = {
                        [1] = TABLE,
                        [2] = NUMBER,
                        [3] = ANY,
                     },
                     ["rets"] = {},
                  },
                  [2] = {
                     ["typename"] = "function",
                     ["args"] = {
                        [1] = TABLE,
                        [2] = ANY,
                     },
                     ["rets"] = {},
                  },
               },
               ["remove"] = {
                  ["typename"] = "poly",
                  [1] = {
                     ["typename"] = "function",
                     ["args"] = {
                        [1] = TABLE,
                        [2] = NUMBER,
                     },
                     ["rets"] = {
                        [1] = ANY,
                     },
                  },
                  [2] = {
                     ["typename"] = "function",
                     ["args"] = {
                        [1] = TABLE,
                     },
                     ["rets"] = {
                        [1] = ANY,
                     },
                  },
               },
            },
         },
         ["type"] = {
            ["typename"] = "function",
            ["args"] = {
               [1] = ANY,
            },
            ["rets"] = {
               [1] = STRING,
            },
         },
         ["assert"] = {
            ["typename"] = "poly",
            [1] = {
               ["typename"] = "function",
               ["args"] = {
                  [1] = BOOLEAN,
               },
               ["rets"] = {},
            },
            [2] = {
               ["typename"] = "function",
               ["args"] = {
                  [1] = BOOLEAN,
                  [2] = STRING,
               },
               ["rets"] = {},
            },
         },
         ["print"] = {
            ["typename"] = "poly",
            [1] = {
               ["typename"] = "function",
               ["args"] = {
                  [1] = ANY,
               },
               ["rets"] = {},
            },
            [2] = {
               ["typename"] = "function",
               ["args"] = {
                  [1] = ANY,
                  [2] = ANY,
               },
               ["rets"] = {},
            },
            [3] = {
               ["typename"] = "function",
               ["args"] = {
                  [1] = ANY,
                  [2] = ANY,
                  [3] = ANY,
               },
               ["rets"] = {},
            },
            [4] = {
               ["typename"] = "function",
               ["args"] = {
                  [1] = ANY,
                  [2] = ANY,
                  [3] = ANY,
                  [4] = ANY,
               },
               ["rets"] = {},
            },
            [5] = {
               ["typename"] = "function",
               ["args"] = {
                  [1] = ANY,
                  [2] = ANY,
                  [3] = ANY,
                  [4] = ANY,
                  [5] = ANY,
               },
               ["rets"] = {},
            },
         },
      },
   }
   local errors = {}
   local function match_type(node, t1, t2)
      assert(type(t1) == "table")
      assert(type(t2) == "table")
      if t2.typename == "any" then
         return true
      end
      if t1.typename ~= t2.typename then
         table.insert(errors, {
            ["y"] = node.y,
            ["x"] = node.x,
            ["err"] = "mismatch: " ..(node.tk or node.op.op) .. " " .. inspect(t1) .. " / " .. inspect(t2),
         })
         return false
      end
      return true
   end
   local function match_func_args(node, func, args)
      assert(type(func) == "table")
      assert(type(args) == "table")
      args = args or{}
      local poly = func.typename == "poly" and func or{
         [1] = func,
      }
      for _, f in ipairs(poly) do
         if f.typename ~= "function" then
            table.insert(errors, {
               ["y"] = node.y,
               ["x"] = node.x,
               ["err"] = "not a function: " .. inspect(f),
            })
            return INVALID
         end
         if#args ==#(f.args or{}) then
            local ok = true
            for i, arg in ipairs(args) do
               if not arg or not match_type(node, arg, f.args[i]) then
                  ok = false
                  break
               end
            end
            if ok == true then
               f.rets.typename = "tuple"
               return f.rets
            end
         end
      end
      return INVALID
   end
   local function match_table_key(node, tbl, key)
      assert(type(tbl) == "table")
      assert(type(key) == "table")
      if tbl.typename ~= "table" then
         table.insert(errors, {
            ["y"] = node.y,
            ["x"] = node.x,
            ["err"] = "not a table: " .. inspect(tbl),
         })
         return INVALID
      end
      if key.typename == "string" or key.typename == "unknown" then
         if tbl.fields[key.tk] then
            return tbl.fields[key.tk]
         end
      end
      return INVALID
   end
   local function untuple(t)
      if t.typename == "tuple" then
         t = t[1]
      end
      if t == nil then
         return NIL
      end
      return t
   end
   local function add_var(var, valtype)
      st[#st][var] = valtype
   end
   local function add_global(var, valtype)
      st[1][var] = valtype
   end
   local visit = {
      ["statements"] = {
         ["before"] = function ()
         table.insert(st, {})
      end,
      ["after"] = function (node, children)
      table.remove(st)
      node.type = {
         ["typename"] = "none",
      }
   end,
},
["local_declaration"] = {
   ["after"] = function (node, children)
   for i, var in ipairs(node.vars) do
      add_var(var.tk, children[2] and children[2][i] or NIL)
   end
   node.type = {
      ["typename"] = "none",
   }
end,
},
["assignment"] = {
   ["after"] = function (node, children)
   for i, var in ipairs(children[1]) do
      if var then
         local val = children[2][i] or NIL
         match_type(node, var, val)
      else
         table.insert(errors, {
            ["y"] = node.y,
            ["x"] = node.x,
            ["err"] = "unknown variable",
         })
      end
   end
   node.type = {
      ["typename"] = "none",
   }
end,
},
["if"] = {
   ["after"] = function (node, children)
   match_type(node, children[1], BOOLEAN)
   node.type = {
      ["typename"] = "none",
   }
end,
},
["while"] = {
   ["after"] = function (node, children)
   match_type(node, children[1], BOOLEAN)
   node.type = {
      ["typename"] = "none",
   }
end,
},
["repeat"] = {
   ["after"] = function (node, children)
   match_type(node, children[2], BOOLEAN)
   node.type = {
      ["typename"] = "none",
   }
end,
},
["do"] = {
   ["after"] = function (node)
   node.type = {
      ["typename"] = "none",
   }
end,
},
["forin"] = {
   ["before"] = function ()
   table.insert(st, {})
end,
["after"] = function (node, children)
table.remove(st)
node.type = {
   ["typename"] = "none",
}
end,
},
["fornum"] = {
   ["before"] = function ()
   table.insert(st, {})
end,
["after"] = function (node, children)
table.remove(st)
node.type = {
   ["typename"] = "none",
}
end,
},
["return"] = {
   ["after"] = function (node, children)
   node.type = children[1]
end,
},
["break"] = {
   ["after"] = function (node, children)
   node.type = {
      ["typename"] = "none",
   }
end,
},
["elseif"] = {
   ["after"] = function (node, children)
   match_type(node, children[1], BOOLEAN)
   node.type = {
      ["typename"] = "none",
   }
end,
},
["variables"] = {
   ["after"] = function (node, children)
   node.type = children
   children.typename = "tuple"
   return children
end,
},
["table_literal"] = {
   ["after"] = function (node, children)
   node.type = {
      ["typename"] = "table",
      ["fields"] = {},
   }
   for _, child in ipairs(children) do
      node.type.fields[child.k] = child.v
   end
   return node.type
end,
},
["table_item"] = {
   ["after"] = function (node, children)
   node.type = {
      ["typename"] = "kv",
      ["k"] = node.key.tk,
      ["v"] = children[2],
   }
end,
},
["local_function"] = {
   ["after"] = function (node, children)
   add_var(node.name.tk, {
      ["typename"] = "function",
      ["args"] = children[2],
      ["rets"] = children[3],
   })
   node.type = {
      ["typename"] = "none",
   }
end,
},
["global_function"] = {
   ["after"] = function (node, children)
   add_global(node.name.tk, {
      ["typename"] = "function",
      ["args"] = children[2],
      ["rets"] = children[3],
   })
   node.type = {
      ["typename"] = "none",
   }
end,
},
["function"] = {
   ["after"] = function (node, children)
   node.type = {
      ["typename"] = "function",
      ["args"] = children[1],
      ["rets"] = {
         ["typename"] = "unknown",
      },
   }
   return node.type
end,
},
["op"] = {
   ["after"] = function (node, children)
   local a = children[1]
   local b = children[3]
   if node.op.op == "@funcall" then
      node.type = match_func_args(node, a, b)
   elseif node.op.op == "@index" then
      node.type = match_table_key(node, a, b)
   elseif node.op.op == "." then
      node.type = match_table_key(node, a, b)
   elseif op_types[node.op.op] then
      a = untuple(a)
      local types_op = op_types[node.op.op][node.op.arity]
      if node.op.arity == 1 then
         node.type = types_op[a.typename]
         if not node.type then
            table.insert(errors, {
               ["y"] = node.y,
               ["x"] = node.x,
               ["err"] = "unop mismatch: " .. node.op.op .. " " .. a.typename,
            })
            node.type = INVALID
         end
      elseif node.op.arity == 2 then
         b = untuple(b)
         node.type = types_op[a.typename] and types_op[a.typename][b.typename]
         if not node.type then
            table.insert(errors, {
               ["y"] = node.y,
               ["x"] = node.x,
               ["err"] = "binop mismatch: " .. node.op.op .. " " .. a.typename .. " " .. b.typename,
            })
            node.type = INVALID
         end
      end
   else
      error("unknown node op " .. node.op.op)
   end
end,
},
["variable"] = {
   ["after"] = function (node, _)
   for i =#st,1,- 1 do
      local scope = st[i]
      if scope[node.tk] then
         node.type = scope[node.tk]
         return scope[node.tk]
      end
   end
   node.type = {
      ["typename"] = "unknown",
      ["tk"] = node.tk,
   }
end,
},
}
visit["values"] = visit["variables"]
visit["expression_list"] = visit["variables"]
visit["argument_list"] = visit["variables"]
visit["word"] = visit["variable"]
visit["string"] = {
   ["after"] = function (node, _)
   node.type = {
      ["typename"] = node.kind,
   }
   return node.type
end,
}
visit["number"] = visit["string"]
visit["nil"] = visit["string"]
visit["boolean"] = visit["string"]
visit["..."] = visit["string"]
visit["@afterafter"] = function (node)
assert(type(node.type) == "table", node.kind .. " did not produce a type")
assert(type(node.type.typename) == "string", node.kind .. " type does not have a typename")
return node.type
end
recurse_ast(ast, visit)
return errors
end
return{
   ["lex"] = lex,
   ["parse_program"] = parse_program,
   ["pretty_print_ast"] = pretty_print_ast,
   ["pretty_print_tokens"] = pretty_print_tokens,
   ["type_check"] = type_check,
}