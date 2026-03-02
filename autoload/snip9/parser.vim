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

# Strip comments and separate out individual snippets.  Handles `extends <ft>`
# as well.
def ExtractRaw(body: list<string>): dict<any>
    var raw_snippets: dict<string> = {}
    var extends: list<string> = []
    var current_trigger = ''
    var current_body = []

    for line in body
        if line =~ '^#' | continue | endif

        var extend_match = matchlist(line, '^extends\s\+\(.*\)')
        if !empty(extend_match)
            var exts = extend_match[1]->split('\v\s*,\s*|\s+')
            extends->extend(exts)
            continue
        endif

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

    return {snippets: raw_snippets, extends: extends}
enddef

# Compiles a single snippet into an AST.
def CompileSnippet(body: string): list<dict<any>>
    # AI powered regex expansion :P

    # Regex helps us make tokens easily.
    const pattern = '\v\\[{}$`\\]|\$\d+|\$\{\d+\}|\$\{\d+:|\$\{VISUAL\}|\`[^\`]*\`|\}'
    var pos = 0

    var root: list<dict<any>> = []
    var stack = [root]
    var mirror: dict<any> = {}  # To initialize empty mirrors.

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
            mirror[id] = node.value
            stack->add(node.value)

        elseif token =~ '^\${\d\+}$'
            var id = str2nr(token[2 : len(token) - 2])
            if mirror->has_key(id)
                stack[-1]->add({type: AST.Mark, id: id, value: mirror[id]})
            else
                stack[-1]->add({type: AST.Mark, id: id})
            endif

        elseif token =~ '^\$\d\+$'
            var id = str2nr(token[1 : len(token) - 1])
            if mirror->has_key(id)
                stack[-1]->add({type: AST.Mark, id: id, value: mirror[id]})
            else
                stack[-1]->add({type: AST.Mark, id: id})
            endif
        endif

        pos = end
    endwhile

    return root
enddef

# Compiles a snippet file into {name: AST}.
def CompileSnippets(filepath: string): dict<any>
    var lines = readfile(filepath)
    var rawfile = ExtractRaw(lines)

    var snippets: dict<list<dict<any>>> = {}
    for [name, body] in items(rawfile.snippets)
        snippets[name] = CompileSnippet(body)
    endfor

    return {snippets: snippets, extends: rawfile.extends}
enddef

# Parses a snippet file for a specific filetype.
# Stores the compiled snippets into memory.
export def ParseSnippets(fulltype: string)
    # Handle ft1.ft2
    var filetypes = fulltype->split('.')
    if empty(filetypes)
        filetypes = [fulltype]
    endif
    filetypes->extend(['_'])

    for ft in filetypes
        if compiled_snippets->has_key(ft) | continue | endif
        compiled_snippets[ft] = {}

        var filepaths = globpath(&runtimepath, 'snippets/' .. ft .. '.snippets', 0, 1)
        for filepath in filepaths
            var result = CompileSnippets(filepath)

            # Inherit snippets from 'extends <ft>'
            for ext in result.extends
                ParseSnippets(ext)
                compiled_snippets[ft]->extend(compiled_snippets[ext], 'keep')
            endfor
            compiled_snippets[ft]->extend(result.snippets, 'force')
        endfor
    endfor
enddef
