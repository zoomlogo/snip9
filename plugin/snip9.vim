vim9script

# Define text property.
if empty(prop_type_get('snippet_mark'))
    prop_type_add('snippet_mark', {
        highlight: 'Search',  # debug
        start_incl: true,
        end_incl: true
    })
endif

# import the engine
import autoload '../autoload/snip9/engine.vim'
import autoload '../autoload/snip9/parser.vim'

# XXX only for debugging:
var compiled_snippets = {
    'c': {
        'once': [
            {type: parser.AST.Text, value: "#pragma once\n"},
            {type: parser.AST.Mark, id: 0},
        ],
        'inc': [
            {type: parser.AST.Text, value: "#include <"},
            {type: parser.AST.Mark, id: 1, value: [{type: parser.AST.Text, value: "stdio"}]},
            {type: parser.AST.Text, value: ".h>\n"},
            {type: parser.AST.Mark, id: 0},
        ],
        'incl': [
            {type: parser.AST.Text, value: "#include \""},
            {type: parser.AST.Mark, id: 1, value: [{type: parser.AST.Text, value: "stdio"}]},
            {type: parser.AST.Text, value: ".h\"\n"},
            {type: parser.AST.Mark, id: 0},
        ],
        'if': [
            {type: parser.AST.Text, value: "if ("},
            {type: parser.AST.Mark, id: 1, value: [{type: parser.AST.Text, value: "cond"}]},
            {type: parser.AST.Text, value: ") {\n\t"},
            {type: parser.AST.Mark, id: 0, value: [{type: parser.AST.Visual}]},
            {type: parser.AST.Text, value: "\n}\n"},
        ],
        'guard': [
            {type: parser.AST.Text, value: "#ifndef "},
            {type: parser.AST.Mark, id: 1, value: [
                {type: parser.AST.Eval, value: 'toupper(expand("%:t:r"))'},
                {type: parser.AST.Text, value: '_DEFINED_H'}
            ]},
            {type: parser.AST.Text, value: "\n#define "},
            {type: parser.AST.Mark, id: 1, value: [
                {type: parser.AST.Eval, value: 'toupper(expand("%:t:r"))'},
                {type: parser.AST.Text, value: '_DEFINED_H'}
            ]},
            {type: parser.AST.Text, value: "\n\n"},
            {type: parser.AST.Mark, id: 0},
            {type: parser.AST.Text, value: "\n\n#endif  // "},
            {type: parser.AST.Mark, id: 1, value: [
                {type: parser.AST.Eval, value: 'toupper(expand("%:t:r"))'},
                {type: parser.AST.Text, value: '_DEFINED_H'}
            ]},
        ],
        'A': [
            {type: parser.AST.Text, value: "testing "},
            {type: parser.AST.Mark, id: 1, value: [
                {type: parser.AST.Text, value: "mark1 "},
                {type: parser.AST.Mark, id: 2, value: [{type: parser.AST.Text, value: "mark2"}]},
            ]},
            {type: parser.AST.Text, value: "\n"},
            {type: parser.AST.Mark, id: 0},
        ],
    }
}

def ExpandWrap(ast: list<dict<any>>)
    engine.SnippetExpand(ast)
enddef

command! -nargs=1 ExpandSnip ExpandWrap(compiled_snippets['c'][<args>])
