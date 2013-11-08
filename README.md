# unite-pull-request

unite-pull-request is a [unite.vim](https://github.com/Shougo/unite.vim "unite.vim") plugin for Viewing GitHub pull request.

## Requirement
- curl
- webapi-vim (https://github.com/mattn/webapi-vim)

## Install

Bundle it!

```vim
NeoBundle 'joker1007/unite-pull-request', {'depends' : 'tpope/vim-fugitive'}
```

## Usage

Add `g:github_token` to your vimrc

```vim
let g:github_token="xxxxxxxxxxxxx"
```

To fetch pull request list of a repository,
execute `:Unite` with `pull_request` source and argument.

```vim
:Unite pull_request:owner/repository_name
```

To fetch pull request changed file list,
execute `:Unite` with `pull_request_file` source and argument.

```vim
:Unite pull_request:owner/repository_name:1
```
