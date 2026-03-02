vim9script

# Define text property.
if empty(prop_type_get('snippet_mark'))
    prop_type_add('snippet_mark', {
        start_incl: true,
        end_incl: true
    })
endif

# import the engine
import autoload '../autoload/snip9/engine.vim'
import autoload '../autoload/snip9/parser.vim'

def SmartBind()
    var col = col('.')
    var line = getline('.')
    var prefix = col == 1 ? '' : line[ : col - 2]
    var curword = matchstr(prefix, '\S\+$')

    var filetypes = &filetype->split('.')
    if empty(filetypes)
        filetypes = [&filetype]
    endif

    for filetype in filetypes
        if has_key(parser.compiled_snippets, filetype) && has_key(parser.compiled_snippets[filetype], curword)
            var start = col - len(curword) - 1
            var nl = (start > 0 ? line[ : start - 1] : '') .. line[col - 1 : ]
            setline('.', nl)
            cursor(line('.'), start + 1)

            engine.SnippetExpand(parser.compiled_snippets[filetype][curword])
        endif
    endfor

    if !empty(prop_find({type: 'snippet_mark', lnum: 1, col: 1}))
        engine.JumpForward()
        return
    endif
enddef

# Autocommand for compiling snippets on demand.
augroup Snip9Compile
    autocmd!
    autocmd FileType * parser.ParseSnippets(expand('<amatch>'))
augroup END

# TODO make these user definable
inoremap <C-j> <ScriptCmd>SmartBind()<CR>
snoremap <C-j> <ScriptCmd>SmartBind()<CR>
xnoremap <C-j> <ScriptCmd>engine.CaptureVisual()<CR>

inoremap <C-k> <ScriptCmd>engine.JumpBackward()<CR>
snoremap <C-k> <ScriptCmd>engine.JumpBackward()<CR>
