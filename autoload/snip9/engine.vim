vim9script

# AST token types
import autoload './parser.vim'

var markers = []
var active_visual_text = ""

const ID_JUMPS = 100
var base_id = 0
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
    # TODO
    # JumpForward()
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

    var keys = "\<Esc>" .. prop.lnum .. "G" .. prop.col .. "|"
    if prop.length > 0
        keys ..= "v" .. (prop.length - 1) .. "l\<C-g>"
    else
        keys ..= "a"
    endif
    feedkeys(keys, 'n')

    if snip.cur == 0
        Cleanup(snip)
    endif
enddef
