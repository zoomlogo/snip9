vim9script

# AST token types
import autoload './parser.vim'

var markers = []
var active_visual_text = ""

const ID_JUMPS = 100
var base_id = 0
# TODO refactor snippet (dict<any>) into a class
var snippet_stack: list<dict<any>> = []

# Evaluate and return a string.
def EvalString(expr: string): string
    # TODO Fix this later (can cause bugs if given lists or dicts).
    return "" .. expr->eval()
enddef

# Recursively expand a snippet from its AST.
def SnippetExpandR(ast: list<dict<any>>, indent: string, parent_id: number, loff: number = 0, coff: number = 0): list<string>
    var lines = [""]

    for token in ast
        var val = ''

        if token.type == parser.AST.Text        # plain text
            val = token.value

        elseif token.type == parser.AST.Eval    # vimscript
            val = EvalString(token.value)

        elseif token.type == parser.AST.Visual  # VISUAL highlight
            val = active_visual_text

        elseif token.type == parser.AST.Mark    # mark
            var m_lnum = loff + len(lines) - 1
            var m_col = (len(lines) == 1 ? coff : 0) + len(lines[-1]) + 1

            var child_ast = token->get('value', [])
            var child_lines = SnippetExpandR(child_ast, indent, parent_id, m_lnum, m_col - 1)
            val = child_lines->join("\n")

            markers->add({
                id: parent_id + token.id,
                line_offset: m_lnum,
                col: m_col,
                len: len(val)
            })
        endif

        # Account for user's whitespace setting.
        if &expandtab
            val = val->substitute('\t', ' '->repeat(shiftwidth()), 'g')
        endif

        var parts = val->split('\n', 1)
        lines[-1] ..= parts[0]
        if len(parts) > 1
            for i in range(1, len(parts) - 1)
                parts[i] = indent .. parts[i]
            endfor
            lines->extend(parts[1 : ])
        endif
    endfor
    return lines
enddef

# Expand a snippet from its AST.
export def SnippetExpand(ast: list<dict<any>>)
    markers = []
    var lnum = line('.')
    var col = col('.')
    var curline = getline(lnum)

    var prefix = col == 1 ? "" : curline[ : col - 2]
    var suffix = curline[col - 1 : ]

    var indent = matchstr(prefix, '^\s*')

    var lines = SnippetExpandR(ast, indent, base_id, 0, len(prefix))
    var max_id = len(markers) - 1
    snippet_stack->add({
        base: base_id,
        max: max_id,
        cur: 0
    })
    base_id += ID_JUMPS

    lines[0] = prefix .. lines[0]
    lines[-1] ..= suffix

    setline(lnum, lines[0])
    if lines->len() > 1
        append(lnum, lines[1 : ])
    endif

    for mark in markers
        prop_add(
            lnum + mark.line_offset,
            mark.col,
            {type: 'snippet_mark', id: mark.id, length: mark.len}
        )
    endfor

    active_visual_text = ""

    augroup Snip9Mirrors
        autocmd! * <buffer>
        autocmd TextChangedI,TextChangedP <buffer> SyncMirrors()
    augroup END
enddef

# Capture visually selected text.
export def CaptureVisual()
    var saved_register = @"
    normal! gv""y
    active_visual_text = @"
    @" = saved_register
    normal! gv"_d
    startinsert
enddef

# Cleans the snippet stack and text-properties.
def Cleanup(snip: dict<any>)
    snippet_stack->remove(-1)
    base_id -= ID_JUMPS
    for i in range(snip.max + 1)
        prop_remove({
            all: true,
            id: snip.base + i,
            type: 'snippet_mark',
            both: true
        })
    endfor

    if empty(snippet_stack)
        augroup Snip9Mirrors
            autocmd! * <buffer>
        augroup END
    endif
enddef

# Jumps to the property and selects it.
def SelectProp(prop: dict<any>)
    var keys = "\<Esc>" .. prop.lnum .. "G" .. prop.col .. "|"
    if prop.length > 0
        keys ..= "v" .. (prop.length - 1) .. "l\<C-g>"
    else
        keys ..= "a"
    endif
    feedkeys(keys, 'n')
enddef

# Jump forwards.  Deletes the snippet marks when it reaches ID 0.
export def JumpForward()
    if empty(snippet_stack) | return | endif

    var snip = snippet_stack[-1]
    snip.cur += 1
    snip.cur = snip.cur > snip.max ? 0 : snip.cur

    var target_id = snip.base + snip.cur
    var prop = prop_find({
        type: 'snippet_mark',
        id: target_id,
        lnum: 1,
        col: 1,
        both: true
    })

    if empty(prop)
        if snip.cur == 0
            Cleanup(snip)
        endif

        JumpForward()
        return
    endif

    SelectProp(prop)

    if snip.cur == 0
        Cleanup(snip)
    endif
enddef

# Jump backwards.  Does not delete the marks.
export def JumpBackward()
    if empty(snippet_stack) | return | endif

    var snip = snippet_stack[-1]
    snip.cur -= 1
    snip.cur = snip.cur < 0 ? snip.max : snip.cur

    var target_id = snip.base + snip.cur
    var prop = prop_find({
        type: 'snippet_mark',
        id: target_id,
        lnum: 1,
        col: 1,
        both: true
    })

    if empty(prop)
        JumpBackward()
        return
    endif

    SelectProp(prop)
enddef

# Mirror handling.
# Update all marks with the same ID to match their texts.
def SyncMirrors()
    var active = prop_find({
        type: 'snippet_mark',
        lnum: line('.'),
        col: col('.')
    })
    if empty(active) | return | endif

    # XXX This is a "hacky" way to kill snippets extending to the next line
    # when the user presses enter.
    var previous = prop_find({
        type: 'snippet_mark',
        id: active.id,
        both: true,
        lnum: line('.'),
        col: col('.'),
        skipstart: true
    }, 'b')
    if !empty(previous) && previous.lnum == active.lnum - 1
        # property spilled over, remove current property
        prop_remove({id: active.id, lnum: active.lnum})
        return
    endif

    var curline = getline(active.lnum)
    var text = curline[active.col - 1 : active.col + active.length - 2]

    var lnums = prop_list(1, {
        end_lnum: line('$'),
        types: ['snippet_mark'],
        ids: [active.id]
    })->map((_, v) => v.lnum)

    for lnum in lnums
        var properties = prop_list(lnum, {types: ['snippet_mark']})
            ->sort((a, b) => a.col - b.col)

        var line = getline(lnum)
        var offset = 0
        var curshift = 0

        for property in properties
            property["lnum"] = lnum
            property.col += offset

            if property == active || property.id != active.id | continue | endif

            var pre = property.col > 1 ? line[: property.col - 2] : ""
            var post = line[property.col + property.length - 1 :]
            line = pre .. text .. post

            var diff = active.length - property.length
            offset += diff
            property.length = active.length

            if lnum == active.lnum && property.col < col('.')
                curshift += diff
            endif
        endfor
        noautocmd setline(lnum, line)

        for property in properties
            prop_add(property.lnum, property.col, {
                type: 'snippet_mark',
                length: property.length,
                id: property.id
            })
        endfor

        if lnum == active.lnum && curshift != 0
            cursor(lnum, col('.') + curshift)
        endif
    endfor
enddef
