const s:dein_base = '~/.cache/dein'

const s:dein_src = s:dein_base . '/repos/github.com/Shougo/dein.vim'

execute 'set runtimepath^=' . s:dein_src

call dein#begin(s:dein_base)

call dein#add(s:dein_src)
call dein#add('prabirshrestha/vim-lsp')
call dein#add('mattn/vim-lsp-settings')

call dein#end()

filetype indent plugin on

if has('syntax')
  syntax on
endif
