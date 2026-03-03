# Snip9
Snip9 is a snippet engine made in Vim9 script.  It is _mostly_ compatible with
snipMate's snippet syntax.

**THIS PLUGIN IS NOT STABLE YET.  IT IS UNDER ACTIVE DEVELOPMENT.**

## Setup.
Requires Vim 9+.

Install using your favourite plugin manager.  The plugin searches for snippets
under a `snippets/` folder in Vim's runtimepath with names `<ft>.snippets` where
`<ft>` is the filetype detected by Vim.  To set the mappings use:
```vim
imap <C-j> <Plug>snip9nextOrTrigger
smap <C-j> <Plug>snip9nextOrTrigger
xmap <C-j> <Plug>snip9visual
imap <C-k> <Plug>snip9back
smap <C-k> <Plug>snip9back
```

An example snippets file is given in the `sample_snippets/` folder of this
repository.

## Completed:
- [x] Snippet Expansion.
- [x] Insert-mode snippet expansion.
- [x] Snippet jumping.
- [x] Nested snippet jumping.
- [x] Mirrored nodes.
- [x] Snippets file parser.
- [x] Snippets files for multiple languages.
- [x] User definable mappings.

## TODO:
- [ ] Write documentation for `:help`.

## Known issues:
- Empty markers enter insert mode in the wrong column.
- Snipmate snippets which use snipmate specific functions cannot be used.

Please open an issue if you find any bugs.
