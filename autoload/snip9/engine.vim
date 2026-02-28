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

# Jump
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

def SelectProp(prop: dict<any>)
    var keys = "\<Esc>" .. prop.lnum .. "G" .. prop.col .. "|"
    if prop.length > 0
        keys ..= "v" .. (prop.length - 1) .. "l\<C-g>"
    else
        keys ..= "a"
    endif
    feedkeys(keys, 'n')
enddef

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
def SyncMirrors()
    var active = prop_find({
        type: 'snippet_mark',
        lnum: line('.')
    })
    if empty(active) | return | endif

    var curline = getline(active.lnum)
    var text = curline[active.col - 1 : active.col + active.length - 2]

    var mirrors = prop_list(1, {
        end_lnum: line('$'),
        types: ['snippet_mark'],
        ids: [active.id]
    })

    var mirrors_linewise = {}
    for mirror in mirrors
        if !mirrors_linewise->has_key(mirror.lnum)
            mirrors_linewise[mirror.lnum] = [mirror]
        else
            mirrors_linewise[mirror.lnum]->add(mirror)
        endif
    endfor

    for mirror in mirrors
        if mirror == active | continue | endif
        var line = getline(mirror.lnum)
        var nline = line[0 : mirror.col - 2] .. text .. line[mirror.col + mirror.length - 1 : -1]
        noautocmd setline(mirror.lnum, nline)
        prop_add(mirror.lnum, mirror.col, {
            type: 'snippet_mark',
            length: active.length,
            id: active.id
        })
    endfor
enddef
