# unite-pull-request

unite-pull-request is a [unite.vim](https://github.com/Shougo/unite.vim "unite.vim") plugin for Viewing GitHub pull request.

Requirement:
- curl
- webapi-vim (https://github.com/mattn/webapi-vim)
- vim-fugitive (https://github.com/tpope/vim-fugitive)


Add `g:github_token` to your vimrc

```vim
let g:github_token="xxxxxxxxxxxxx"
```

Change current directory to Git project, before use it.
Because this plugin uses vim-fugitive to open Git blob file

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
