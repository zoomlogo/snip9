vim9script

# Options
g:snip9_smartexpand = get(g:, 'snip9_smartexpand', '<C-j>')
g:snip9_jumpback = get(g:, 'snip9_jumpback', '<C-k>')

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

def SetupMappings()
    execute "inoremap <silent> " .. g:snip9_smartexpand .. " <ScriptCmd>SmartBind()<CR>"
    execute "snoremap <silent> " .. g:snip9_smartexpand .. " <ScriptCmd>SmartBind()<CR>"
    execute "xnoremap <silent> " .. g:snip9_smartexpand .. " <ScriptCmd>engine.CaptureVisual()<CR>"

    execute "inoremap <silent> " .. g:snip9_jumpback .. " <ScriptCmd>engine.JumpBackward()<CR>"
    execute "snoremap <silent> " .. g:snip9_jumpback .. " <ScriptCmd>engine.JumpBackward()<CR>"
enddef

# Autocommand for compiling snippets on demand.
augroup Snip9Compile
    autocmd!
    autocmd FileType * parser.ParseSnippets(expand('<amatch>'))
augroup END


SetupMappings()
