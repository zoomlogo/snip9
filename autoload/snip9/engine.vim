vim9script

# AST token types
import autoload './parser.vim'

var markers = []
var active_visual_text = ""

# Evaluate and return a string.
def EvalString(expr: string): string
    # TODO Fix this later (can cause bugs if given lists or dicts).
    return "" .. expr->eval()
enddef

# Expand a snippet from its AST.
# Recursively calls itself to handle AST.Mark.
def SnippetExpandR(ast: list<dict<any>>, loff: number = 0, coff: number = 0): list<string>
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
            var child_lines = SnippetExpandR(child_ast, m_lnum, m_col - 1)
            val = child_lines->join("\n")

            markers->add({
                id: token.id,
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

    var lines = SnippetExpandR(ast, 0, len(prefix))
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
