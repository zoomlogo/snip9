vim9script

# Stores the compiled snippets.
export var compiled_snippets = {}

# AST token types.
export enum AST
    Text,
    Mark,
    Eval,
    Visual
endenum

# Strip comments and separate out individual snippets
# TODO `extends <ft>`
def ExtractRaw(body: list<string>): dict<string>
    var raw_snippets = {}
    var current_trigger = ''
    var current_body = []

    for line in body
        if line =~ '^#' | continue | endif

        var start_snippet = matchlist(line, '^snippet\s\+\(\S\+\)')
        if !empty(start_snippet)
            if current_trigger != ''
                raw_snippets[current_trigger] = current_body->join("\n")
            endif

            current_trigger = start_snippet[1]
            current_body = []
            continue
        endif

        if current_trigger != ''
            if line =~ '^\t'
                current_body->add(substitute(line, '\t', '', ''))
            elseif line =~ '^\s*$'
                current_body->add('')
            endif
        endif
    endfor

    if current_trigger != ''
        raw_snippets[current_trigger] = current_body->join("\n")
    endif

    return raw_snippets
enddef

# Compiles a single snippet into an AST.
def CompileSnippet(body: string): list<dict<any>>
    const pattern = '\v\\[{}$`\\]|\$\d+|\$\{\d+\}|\$\{\d+:|\$\{VISUAL\}|\`[^\`]*\`|\}'
    var pos = 0

    var root: list<dict<any>> = []
    var stack = [root]

    while pos < len(body)
        var match = matchstrpos(body, pattern, pos)
        var token = match[0]
        var start = match[1]
        var end = match[2]

        if start == -1
            var text = body[pos : len(body) - 1]
            if text != ''
                stack[-1]->add({type: AST.Text, value: text})
            endif
            break
        endif

        if start > pos
            stack[-1]->add({type: AST.Text, value: body[pos : start - 1]})
        endif

        if token[0] == '\'
            stack[-1]->add({type: AST.Text, value: token[1]})
        elseif token == '${VISUAL}'
            stack[-1]->add({type: AST.Visual})
        elseif token =~ '^\`'
            var code = token[1 : len(token) - 2]
            stack[-1]->add({type: AST.Eval, value: code})
        elseif token == '}'
            if len(stack) > 1
                stack->remove(-1)
            else
                stack[-1]->add({type: AST.Text, value: '}'})
            endif
        elseif token =~ '^\${\d\+:$'
            var id = str2nr(token[2 : len(token) - 2])
            var node = {type: AST.Mark, id: id, value: []}
            stack[-1]->add(node)
            stack->add(node.value)
        elseif token =~ '^\${\d\+}$'
            var id = str2nr(token[2 : len(token) - 2])
            stack[-1]->add({type: AST.Mark, id: id})
        elseif token =~ '^\$\d\+$'
            var id = str2nr(token[1 : len(token) - 1])
            stack[-1]->add({type: AST.Mark, id: id})
        endif

        pos = end
    endwhile

    return root
enddef

# Compiles a snippet file into {name: AST}.
def CompileSnippets(filepath: string): dict<list<dict<any>>>
    var lines = readfile(filepath)
    var blocks = ExtractRaw(lines)

    var snippets = {}
    for [name, body] in blocks
        snippets[name] = CompileSnippet(body)
    endfor

    return snippets
enddef

# Parses a snippet file for a specific filetype.
# Stores the compiled snippets into memory.
def ParseSnippets(fulltype: string)
    # Handle ft1.ft2
    var filetypes = fulltype->split('.')
    for ft in filetypes
        if compiled_snippets->has_key(ft) | continue | endif

        var filepaths = globpath(&runtimepath, 'snippets/' .. ft .. '.snippets', 0, 1)
        for filepath in filepaths
            compiled_snippets[ft]->extend(CompileSnippets(filepath))
        endfor
    endfor
enddef

# Autocommand for compiling snippets on demand.
augroup Snip9Compile
    autocmd!
    autocmd FileType * ParseSnippets(expand('<amatch>'))
augroup END
