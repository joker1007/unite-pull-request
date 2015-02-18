# unite-pull-request

unite-pull-request is a [unite.vim](https://github.com/Shougo/unite.vim "unite.vim") plugin for Viewing GitHub pull request.

## Requirement
- curl
- webapi-vim (https://github.com/mattn/webapi-vim)


## Usage

Add `g:github_user` to your vimrc

```vim
let g:github_user="<your github user id>"
```

To fetch pull request list of a repository,
execute `:Unite` with `pull_request` source and argument.

```vim
:Unite pull_request:owner/repository_name
```

If current directory is git repository and set github url as remote "origin",
you don't need argument.

```vim
:Unite pull_request
```

To fetch pull request changed file list,
execute `:Unite` with `pull_request_file` source and argument.

```vim
:Unite pull_request:owner/repository_name:1
```

## ScreenShots
![スクリーンショット 2013-11-09 5.50.35.png](https://qiita-image-store.s3.amazonaws.com/0/78/a4cdd623-574f-de70-f912-de677480dd34.png)
![スクリーンショット 2013-11-09 5.51.03.png](https://qiita-image-store.s3.amazonaws.com/0/78/f65171ba-bdc8-1cda-cb80-b34a36ae8a3f.png)
![スクリーンショット 2013-11-09 5.51.22.png](https://qiita-image-store.s3.amazonaws.com/0/78/18f20f86-bb70-2fdf-673e-c809102e188e.png)
