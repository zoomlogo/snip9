vim9script

# AST token types.
export const AST_Text = 0
export const AST_Mark = 1
export const AST_Eval = 2
export const AST_Visual = 3
export enum AST
    Text,
    Mark,
    Eval,
    Visual
endenum
